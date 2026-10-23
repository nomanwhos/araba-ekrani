import XCTest
@testable import Torpido

@MainActor
private final class FakePlayback: CastPlayback {
    var calls: [String] = []
    var castState = "STOPPED"
    var castPosition = 65.0
    var castDuration = 3600.0

    func playCast(_ url: URL, title: String) { calls.append("play \(url.absoluteString) \(title)"); castState = "PLAYING" }
    func resumeCast() { calls.append("resume") }
    func pauseCast() { calls.append("pause") }
    func stopCast() { calls.append("stop") }
    func seekCast(to seconds: Double) { calls.append("seek \(Int(seconds))") }
}

@MainActor
final class DLNARendererTests: XCTestCase {
    private func soap(_ action: String, _ inner: String = "<InstanceID>0</InstanceID>") -> HTTPRequest {
        let body = """
        <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>\
        <u:\(action) xmlns:u="\(UPnP.avTransport)">\(inner)</u:\(action)></s:Body></s:Envelope>
        """
        return HTTPRequest(method: "POST", path: "/AVTransport/control",
                           headers: ["soapaction": "\"\(UPnP.avTransport)#\(action)\""], body: Data(body.utf8))
    }

    private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

    func testCastFlowDrivesThePlayer() {
        let playback = FakePlayback()
        let renderer = DLNARenderer(playback: playback, uuid: "test-uuid")
        let metadata = XML.escape("<DIDL-Lite><item><dc:title>Haber Özeti</dc:title></item></DIDL-Lite>")

        let set = text(renderer.respond(to: soap("SetAVTransportURI",
            "<InstanceID>0</InstanceID><CurrentURI>http://10.0.0.9/v.mp4</CurrentURI><CurrentURIMetaData>\(metadata)</CurrentURIMetaData>")))
        _ = renderer.respond(to: soap("Pause"))
        _ = renderer.respond(to: soap("Seek", "<InstanceID>0</InstanceID><Unit>REL_TIME</Unit><Target>0:01:30</Target>"))
        _ = renderer.respond(to: soap("Play", "<InstanceID>0</InstanceID><Speed>1</Speed>"))
        _ = renderer.respond(to: soap("Stop"))

        XCTAssertTrue(set.hasPrefix("HTTP/1.1 200 OK"))
        XCTAssertTrue(set.contains("SetAVTransportURIResponse"))
        XCTAssertEqual(playback.calls, ["play http://10.0.0.9/v.mp4 Haber Özeti", "pause", "seek 90", "resume", "stop"])
        XCTAssertEqual(renderer.castTitle, "Haber Özeti")
    }

    func testRejectsNonHTTPURIs() {
        let playback = FakePlayback()
        let renderer = DLNARenderer(playback: playback, uuid: "test-uuid")

        let reply = text(renderer.respond(to: soap("SetAVTransportURI", "<InstanceID>0</InstanceID><CurrentURI>file:///etc/passwd</CurrentURI>")))

        XCTAssertTrue(reply.hasPrefix("HTTP/1.1 500"))
        XCTAssertTrue(playback.calls.isEmpty)
    }

    func testReportsPositionAndState() {
        let playback = FakePlayback()
        playback.castState = "PLAYING"
        let renderer = DLNARenderer(playback: playback, uuid: "test-uuid")

        let position = text(renderer.respond(to: soap("GetPositionInfo")))
        let transport = text(renderer.respond(to: soap("GetTransportInfo")))

        XCTAssertTrue(position.contains("<RelTime>0:01:05</RelTime>"))
        XCTAssertTrue(position.contains("<TrackDuration>1:00:00</TrackDuration>"))
        XCTAssertTrue(transport.contains("<CurrentTransportState>PLAYING</CurrentTransportState>"))
    }

    func testServesDescriptionAndRejectsUnknownPaths() {
        let renderer = DLNARenderer(playback: nil, uuid: "test-uuid")

        let description = text(renderer.respond(to: HTTPRequest(method: "GET", path: "/description.xml", headers: [:], body: Data())))
        let missing = text(renderer.respond(to: HTTPRequest(method: "GET", path: "/etc/passwd", headers: [:], body: Data())))
        let unknown = text(renderer.respond(to: soap("Record")))

        XCTAssertTrue(description.contains("<UDN>uuid:test-uuid</UDN>"))
        XCTAssertTrue(missing.hasPrefix("HTTP/1.1 404"))
        XCTAssertTrue(unknown.contains("<errorCode>401</errorCode>"))
    }

    func testHTTPServerAnswersOverTheNetwork() async throws {
        let renderer = DLNARenderer(playback: FakePlayback(), uuid: "net-uuid")
        renderer.start(announce: false, keepAwake: false)
        defer { renderer.stop() }
        for _ in 0..<100 where renderer.port == nil { try await Task.sleep(for: .milliseconds(50)) }
        let port = try XCTUnwrap(renderer.port)

        let (data, response) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/description.xml")!)

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("uuid:net-uuid"))
    }
}
