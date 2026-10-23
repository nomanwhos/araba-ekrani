import Foundation

/// One HTTP request read off a TCP connection (UPnP control points speak plain HTTP/1.1).
struct HTTPRequest: Equatable {
    var method: String
    var path: String
    var headers: [String: String]   // lower-cased names
    var body: Data

    func header(_ name: String) -> String? { headers[name.lowercased()] }

    /// Parses a complete request; nil while more bytes are needed.
    static func parse(_ data: Data) -> HTTPRequest? {
        guard let split = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[data.startIndex..<split.lowerBound], encoding: .utf8) else { return nil }
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()] =
                line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = split.upperBound
        guard data.distance(from: bodyStart, to: data.endIndex) >= length else { return nil }
        let body = data[bodyStart..<data.index(bodyStart, offsetBy: length)]
        return HTTPRequest(method: String(requestLine[0]), path: String(requestLine[1]), headers: headers, body: Data(body))
    }
}

enum HTTPResponse {
    static func make(status: String = "200 OK", contentType: String = "text/xml; charset=\"utf-8\"",
                     body: String = "", extraHeaders: [String: String] = [:]) -> Data {
        let bodyData = Data(body.utf8)
        var head = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(bodyData.count)\r\n"
        head += "Server: \(UPnP.serverName)\r\nConnection: close\r\n"
        for (name, value) in extraHeaders.sorted(by: { $0.key < $1.key }) { head += "\(name): \(value)\r\n" }
        return Data((head + "\r\n").utf8) + bodyData
    }
}

/// A SOAP action call from a control point: `SOAPACTION: "urn:...:AVTransport:1#Play"`.
struct SOAPAction: Equatable {
    var serviceType: String
    var name: String
    var arguments: [String: String]

    init?(soapActionHeader: String?, body: Data) {
        guard let header = soapActionHeader?.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")),
              let hash = header.lastIndex(of: "#") else { return nil }
        serviceType = String(header[..<hash])
        name = String(header[header.index(after: hash)...])
        arguments = Self.arguments(in: String(decoding: body, as: UTF8.self), action: name)
    }

    /// The direct children of `<u:Action>`: name -> unescaped text.
    private static func arguments(in xml: String, action: String) -> [String: String] {
        guard let open = xml.range(of: ":\(action)", options: .caseInsensitive),
              let start = xml[open.upperBound...].firstIndex(of: ">") else { return [:] }
        var result: [String: String] = [:]
        let inner = xml[xml.index(after: start)...]
        let pattern = try? NSRegularExpression(pattern: "<([A-Za-z][\\w]*)(?:\\s[^>]*)?>(.*?)</\\1>|<([A-Za-z][\\w]*)\\s*/>",
                                               options: [.dotMatchesLineSeparators])
        let text = String(inner)
        for match in pattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? [] {
            if let name = Range(match.range(at: 1), in: text), let value = Range(match.range(at: 2), in: text) {
                result[String(text[name])] = XML.unescape(String(text[value]))
            } else if let empty = Range(match.range(at: 3), in: text) {
                result[String(text[empty])] = ""
            }
        }
        return result
    }
}

enum XML {
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    /// `<dc:title>` from DIDL-Lite metadata, if any.
    static func didlTitle(_ metadata: String) -> String? {
        guard let open = metadata.range(of: "<dc:title>"), let close = metadata.range(of: "</dc:title>", range: open.upperBound..<metadata.endIndex)
        else { return nil }
        let title = unescape(String(metadata[open.upperBound..<close.lowerBound])).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
}

/// UPnP AV constants, the device description and the SSDP messages.
enum UPnP {
    static let serverName = "iOS/18 UPnP/1.0 Torpido/0.1"
    static let deviceType = "urn:schemas-upnp-org:device:MediaRenderer:1"
    static let avTransport = "urn:schemas-upnp-org:service:AVTransport:1"
    static let renderingControl = "urn:schemas-upnp-org:service:RenderingControl:1"
    static let connectionManager = "urn:schemas-upnp-org:service:ConnectionManager:1"
    static let ssdpHost = "239.255.255.250"
    static let ssdpPort: UInt16 = 1900
    static let maxAge = 1800

    struct Service {
        var type: String
        var id: String
        var path: String
        var actions: [(name: String, inArgs: [String], outArgs: [String])]
    }

    static let services: [Service] = [
        Service(type: avTransport, id: "urn:upnp-org:serviceId:AVTransport", path: "AVTransport", actions: [
            ("SetAVTransportURI", ["InstanceID", "CurrentURI", "CurrentURIMetaData"], []),
            ("Play", ["InstanceID", "Speed"], []), ("Pause", ["InstanceID"], []), ("Stop", ["InstanceID"], []),
            ("Seek", ["InstanceID", "Unit", "Target"], []),
            ("GetTransportInfo", ["InstanceID"], ["CurrentTransportState", "CurrentTransportStatus", "CurrentSpeed"]),
            ("GetPositionInfo", ["InstanceID"], ["Track", "TrackDuration", "TrackMetaData", "TrackURI", "RelTime", "AbsTime", "RelCount", "AbsCount"]),
            ("GetMediaInfo", ["InstanceID"], ["NrTracks", "MediaDuration", "CurrentURI", "CurrentURIMetaData", "NextURI", "NextURIMetaData", "PlayMedium", "RecordMedium", "WriteStatus"]),
        ]),
        Service(type: renderingControl, id: "urn:upnp-org:serviceId:RenderingControl", path: "RenderingControl", actions: [
            ("GetVolume", ["InstanceID", "Channel"], ["CurrentVolume"]), ("SetVolume", ["InstanceID", "Channel", "DesiredVolume"], []),
            ("GetMute", ["InstanceID", "Channel"], ["CurrentMute"]), ("SetMute", ["InstanceID", "Channel", "DesiredMute"], []),
        ]),
        Service(type: connectionManager, id: "urn:upnp-org:serviceId:ConnectionManager", path: "ConnectionManager", actions: [
            ("GetProtocolInfo", [], ["Source", "Sink"]), ("GetCurrentConnectionIDs", [], ["ConnectionIDs"]),
            ("GetCurrentConnectionInfo", ["ConnectionID"], ["RcsID", "AVTransportID", "ProtocolInfo", "PeerConnectionManager", "PeerConnectionID", "Direction", "Status"]),
        ]),
    ]

    static func deviceDescription(uuid: String, friendlyName: String) -> String {
        let serviceList: String = services.map { s in
            "<service><serviceType>\(s.type)</serviceType><serviceId>\(s.id)</serviceId>"
                + "<SCPDURL>/\(s.path)/scpd.xml</SCPDURL><controlURL>/\(s.path)/control</controlURL>"
                + "<eventSubURL>/\(s.path)/event</eventSubURL></service>"
        }.joined()
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <root xmlns="urn:schemas-upnp-org:device-1-0" xmlns:dlna="urn:schemas-dlna-org:device-1-0">\
        <specVersion><major>1</major><minor>0</minor></specVersion><device>\
        <deviceType>\(deviceType)</deviceType><friendlyName>\(XML.escape(friendlyName))</friendlyName>\
        <manufacturer>Torpido</manufacturer><modelName>Torpido</modelName><modelNumber>1</modelNumber>\
        <dlna:X_DLNADOC>DMR-1.50</dlna:X_DLNADOC><UDN>uuid:\(uuid)</UDN>\
        <serviceList>\(serviceList)</serviceList></device></root>
        """
    }

    /// Service description: every action, every argument typed as a string.
    static func scpd(for service: Service) -> String {
        let actions: String = service.actions.map { action -> String in
            let args = action.inArgs.map { arg("\($0)", "in") } + action.outArgs.map { arg("\($0)", "out") }
            return "<action><name>\(action.name)</name><argumentList>\(args.joined())</argumentList></action>"
        }.joined()
        let names = Set(service.actions.flatMap { $0.inArgs + $0.outArgs })
        let variables: String = names.sorted().map {
            "<stateVariable sendEvents=\"no\"><name>A_ARG_TYPE_\($0)</name><dataType>string</dataType></stateVariable>"
        }.joined()
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <scpd xmlns="urn:schemas-upnp-org:service-1-0"><specVersion><major>1</major><minor>0</minor></specVersion>\
        <actionList>\(actions)</actionList><serviceStateTable>\(variables)</serviceStateTable></scpd>
        """
    }

    private static func arg(_ name: String, _ direction: String) -> String {
        "<argument><name>\(name)</name><direction>\(direction)</direction><relatedStateVariable>A_ARG_TYPE_\(name)</relatedStateVariable></argument>"
    }

    static func soapResponse(action: String, serviceType: String, values: [(String, String)] = []) -> String {
        let body: String = values.map { "<\($0.0)>\(XML.escape($0.1))</\($0.0)>" }.joined()
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body><u:\(action)Response xmlns:u="\(serviceType)">\(body)</u:\(action)Response></s:Body></s:Envelope>
        """
    }

    static func soapFault(code: Int, description: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail>\
        <UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>\(code)</errorCode>\
        <errorDescription>\(XML.escape(description))</errorDescription></UPnPError></detail></s:Fault></s:Body></s:Envelope>
        """
    }

    /// Every notification type this device announces: root, UUID, device type, each service.
    static func notificationTypes(uuid: String) -> [String] {
        ["upnp:rootdevice", "uuid:\(uuid)", deviceType] + services.map(\.type)
    }

    static func usn(uuid: String, type: String) -> String {
        type == "uuid:\(uuid)" ? type : "uuid:\(uuid)::\(type)"
    }

    /// Replies to an M-SEARCH, or nothing when the search is for something we are not.
    static func searchResponses(to message: String, uuid: String, location: String) -> [String] {
        guard message.hasPrefix("M-SEARCH"),
              let stLine = message.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("st:") }) else { return [] }
        let target = stLine.dropFirst(3).trimmingCharacters(in: .whitespaces)
        let ours = notificationTypes(uuid: uuid)
        let matches = target == "ssdp:all" ? ours : ours.filter { $0 == target }
        return matches.map { st in
            "HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=\(maxAge)\r\nEXT:\r\nLOCATION: \(location)\r\n"
                + "SERVER: \(serverName)\r\nST: \(st)\r\nUSN: \(usn(uuid: uuid, type: st))\r\n\r\n"
        }
    }

    static func notify(alive: Bool, uuid: String, location: String) -> [String] {
        notificationTypes(uuid: uuid).map { nt in
            var message = "NOTIFY * HTTP/1.1\r\nHOST: \(ssdpHost):\(ssdpPort)\r\nNT: \(nt)\r\nNTS: ssdp:\(alive ? "alive" : "byebye")\r\n"
            message += "USN: \(usn(uuid: uuid, type: nt))\r\n"
            if alive { message += "CACHE-CONTROL: max-age=\(maxAge)\r\nLOCATION: \(location)\r\nSERVER: \(serverName)\r\n" }
            return message + "\r\n"
        }
    }

    /// "1:02:03" <-> seconds, the UPnP time format.
    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }

    static func seconds(_ time: String) -> Double? {
        let parts = time.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 3 else { return nil }
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }
}
