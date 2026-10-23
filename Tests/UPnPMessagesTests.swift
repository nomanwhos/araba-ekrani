import XCTest
@testable import Torpido

final class UPnPMessagesTests: XCTestCase {
    private let uuid = "1234-abcd"
    private let location = "http://192.168.1.5:49200/description.xml"

    func testHTTPRequestWaitsForTheWholeBody() {
        let full = Data("POST /AVTransport/control HTTP/1.1\r\nContent-Length: 4\r\nSOAPACTION: \"x#Play\"\r\n\r\nabcd".utf8)

        XCTAssertNil(HTTPRequest.parse(full.prefix(full.count - 2)))
        let request = HTTPRequest.parse(full)
        XCTAssertEqual(request?.method, "POST")
        XCTAssertEqual(request?.path, "/AVTransport/control")
        XCTAssertEqual(request?.header("SoapAction"), "\"x#Play\"")
        XCTAssertEqual(request?.body, Data("abcd".utf8))
    }

    func testSetURIActionReadsURIAndDIDLTitle() throws {
        let body = """
        <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>
        <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
        <InstanceID>0</InstanceID>
        <CurrentURI>http://10.0.0.2:8080/film.mp4?a=1&amp;b=2</CurrentURI>
        <CurrentURIMetaData>&lt;DIDL-Lite&gt;&lt;item&gt;&lt;dc:title&gt;Kamp Gecesi &amp;amp; Yıldızlar&lt;/dc:title&gt;&lt;/item&gt;&lt;/DIDL-Lite&gt;</CurrentURIMetaData>
        </u:SetAVTransportURI></s:Body></s:Envelope>
        """

        let action = try XCTUnwrap(SOAPAction(soapActionHeader: "\"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI\"",
                                              body: Data(body.utf8)))

        XCTAssertEqual(action.name, "SetAVTransportURI")
        XCTAssertEqual(action.serviceType, UPnP.avTransport)
        XCTAssertEqual(action.arguments["CurrentURI"], "http://10.0.0.2:8080/film.mp4?a=1&b=2")
        XCTAssertEqual(XML.didlTitle(action.arguments["CurrentURIMetaData"] ?? ""), "Kamp Gecesi & Yıldızlar")
    }

    func testEmptyElementsAreReadAsEmptyArguments() throws {
        let body = "<s:Body><u:SetAVTransportURI xmlns:u=\"x\"><InstanceID>0</InstanceID><CurrentURIMetaData/></u:SetAVTransportURI></s:Body>"

        let action = try XCTUnwrap(SOAPAction(soapActionHeader: "x#SetAVTransportURI", body: Data(body.utf8)))

        XCTAssertEqual(action.arguments["CurrentURIMetaData"], "")
    }

    func testSearchAnswersOnlyForOurTypes() {
        let search = { (st: String) in "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: \(st)\r\n\r\n" }

        XCTAssertEqual(UPnP.searchResponses(to: search("ssdp:all"), uuid: uuid, location: location).count, 6)
        let renderer = UPnP.searchResponses(to: search(UPnP.deviceType), uuid: uuid, location: location)
        XCTAssertEqual(renderer.count, 1)
        XCTAssertTrue(renderer[0].contains("LOCATION: \(location)\r\n"))
        XCTAssertTrue(renderer[0].contains("USN: uuid:\(uuid)::\(UPnP.deviceType)\r\n"))
        XCTAssertEqual(UPnP.searchResponses(to: search("urn:schemas-upnp-org:device:MediaServer:1"), uuid: uuid, location: location), [])
        XCTAssertEqual(UPnP.searchResponses(to: "NOTIFY * HTTP/1.1\r\n\r\n", uuid: uuid, location: location), [])
    }

    func testNotifyAliveAndByeBye() {
        let alive = UPnP.notify(alive: true, uuid: uuid, location: location)
        let bye = UPnP.notify(alive: false, uuid: uuid, location: location)

        XCTAssertEqual(alive.count, 6)
        XCTAssertTrue(alive.allSatisfy { $0.contains("NTS: ssdp:alive") && $0.contains("LOCATION: ") })
        XCTAssertTrue(bye.allSatisfy { $0.contains("NTS: ssdp:byebye") && !$0.contains("LOCATION") })
    }

    func testDescriptionNamesTheRendererAndItsServices() {
        let xml = UPnP.deviceDescription(uuid: uuid, friendlyName: "Torpido (iPhone)")

        XCTAssertTrue(xml.contains("<UDN>uuid:\(uuid)</UDN>"))
        XCTAssertTrue(xml.contains("<friendlyName>Torpido (iPhone)</friendlyName>"))
        XCTAssertTrue(xml.contains("<controlURL>/AVTransport/control</controlURL>"))
        XCTAssertTrue(UPnP.scpd(for: UPnP.services[0]).contains("<name>SetAVTransportURI</name>"))
    }

    func testTimeFormatRoundTrips() {
        XCTAssertEqual(UPnP.time(3723), "1:02:03")
        XCTAssertEqual(UPnP.time(.nan), "0:00:00")
        XCTAssertEqual(UPnP.seconds("1:02:03"), 3723)
        XCTAssertNil(UPnP.seconds("abc"))
    }
}
