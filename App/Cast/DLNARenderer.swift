import AVFoundation
import Darwin
import Foundation
import Network
import Observation

/// What the receiver needs from the player; PlayerController in the app, a fake in tests.
@MainActor
protocol CastPlayback: AnyObject {
    func playCast(_ url: URL, title: String)
    func resumeCast()
    func pauseCast()
    func stopCast()
    func seekCast(to seconds: Double)
    /// "PLAYING", "PAUSED_PLAYBACK", "STOPPED" or "NO_MEDIA_PRESENT".
    var castState: String { get }
    var castPosition: Double { get }
    var castDuration: Double { get }
}

/// Torpido as a DLNA/UPnP media renderer on the local network.
/// Other apps' Cast buttons find it over SSDP (multicast 239.255.255.250:1900),
/// read its description over HTTP and send it a video URL with SOAP commands.
/// Runs only while switched on; while on, a silent audio track keeps the app awake
/// so a cast can arrive while another app on the same iPhone is in front.
@MainActor
@Observable
final class DLNARenderer {
    static let shared = DLNARenderer(playback: PlayerController.shared)
    static let enabledKey = "castReceiverOn"

    private static let notifyInterval: TimeInterval = 60
    private static let maxRequestBytes = 1 << 20

    private(set) var isOn = false
    private(set) var address: String?
    private(set) var problem: String?
    private(set) var castTitle: String?

    let friendlyName: String
    let uuid: String
    @ObservationIgnored weak var playback: CastPlayback?
    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var ssdp: NWConnectionGroup?
    @ObservationIgnored private var notifyTimer: Timer?
    @ObservationIgnored private var currentURI = ""
    @ObservationIgnored private var currentMetadata = ""
    @ObservationIgnored private let keepAwake = SilentAudioKeepAlive()
    @ObservationIgnored private let queue = DispatchQueue(label: "torpido.dlna")

    init(playback: CastPlayback?, friendlyName: String = "Torpido (iPhone)", uuid: String = DLNARenderer.storedUUID()) {
        self.playback = playback
        self.friendlyName = friendlyName
        self.uuid = uuid
    }

    /// The on/off switch on the cast screen; remembered across launches.
    func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
        on ? start() : stop()
    }

    /// Turns the receiver back on at launch if it was left on.
    func restore() {
        if UserDefaults.standard.bool(forKey: Self.enabledKey) { start() }
    }

    /// `announce: false` serves HTTP only (tests run without multicast).
    func start(announce: Bool = true, keepAwake shouldKeepAwake: Bool = true) {
        guard !isOn else { return }
        problem = nil
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in self?.listenerChanged(state, announce: announce) }
            }
            listener.start(queue: queue)
            self.listener = listener
            isOn = true
            if shouldKeepAwake { keepAwake.start() }
        } catch {
            problem = String(localized: "Alıcı başlatılamadı: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard isOn else { return }
        if let location { sendNotify(alive: false, location: location) }
        notifyTimer?.invalidate()
        notifyTimer = nil
        ssdp?.cancel()
        ssdp = nil
        listener?.cancel()
        listener = nil
        keepAwake.stop()
        isOn = false
        address = nil
    }

    /// Set once the listener is ready; before that NWListener reports port 0.
    var port: UInt16? { address == nil ? nil : listener?.port?.rawValue }

    private var location: String? {
        guard let port, let ip = Self.wifiAddress() ?? (address == "127.0.0.1" ? address : nil) else { return nil }
        return "http://\(ip):\(port)/description.xml"
    }

    // MARK: - Discovery

    private func listenerChanged(_ state: NWListener.State, announce: Bool) {
        switch state {
        case .ready:
            address = Self.wifiAddress() ?? "127.0.0.1"
            if announce { startSSDP() }
        case .failed(let error):
            problem = String(localized: "Alıcı başlatılamadı: \(error.localizedDescription)")
            stop()
        default:
            break
        }
    }

    private func startSSDP() {
        guard Self.wifiAddress() != nil else {
            problem = String(localized: "Wi-Fi'ye bağlı değil. Alıcı yalnızca aynı Wi-Fi ağındaki uygulamalara görünür.")
            return
        }
        do {
            let group = NWConnectionGroup(
                with: try NWMulticastGroup(for: [.hostPort(host: .init(UPnP.ssdpHost), port: .init(rawValue: UPnP.ssdpPort)!)]),
                using: {
                    let parameters = NWParameters.udp
                    parameters.allowLocalEndpointReuse = true
                    return parameters
                }())
            group.setReceiveHandler(maximumMessageSize: 16_384, rejectOversizedMessages: true) { [weak self] message, content, _ in
                guard let content, let text = String(data: content, encoding: .utf8) else { return }
                Task { @MainActor in
                    guard let self, let location = self.location else { return }
                    for reply in UPnP.searchResponses(to: text, uuid: self.uuid, location: location) {
                        message.reply(content: Data(reply.utf8))
                    }
                }
            }
            group.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    if case .ready = state, let location = self.location { self.sendNotify(alive: true, location: location) }
                    if case .failed(let error) = state {
                        self.problem = String(localized: "Ağda görünme başlatılamadı: \(error.localizedDescription)")
                    }
                }
            }
            group.start(queue: queue)
            ssdp = group
            notifyTimer = Timer.scheduledTimer(withTimeInterval: Self.notifyInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let location = self.location else { return }
                    self.sendNotify(alive: true, location: location)
                }
            }
        } catch {
            problem = String(localized: "Ağda görünme başlatılamadı: \(error.localizedDescription)")
        }
    }

    private func sendNotify(alive: Bool, location: String) {
        for message in UPnP.notify(alive: alive, uuid: uuid, location: location) {
            ssdp?.send(content: Data(message.utf8)) { _ in }
        }
    }

    // MARK: - HTTP

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                var buffer = buffer
                if let data { buffer.append(data) }
                if let request = HTTPRequest.parse(buffer) {
                    let response = self.respond(to: request)
                    connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
                } else if isComplete || error != nil || buffer.count > Self.maxRequestBytes {
                    connection.cancel()
                } else {
                    self.receive(on: connection, buffer: buffer)
                }
            }
        }
    }

    /// Routes one request. Internal so tests can call it without a socket.
    func respond(to request: HTTPRequest) -> Data {
        let path = request.path.components(separatedBy: "?").first ?? request.path
        if request.method == "GET", path == "/description.xml" {
            return HTTPResponse.make(body: UPnP.deviceDescription(uuid: uuid, friendlyName: friendlyName))
        }
        for service in UPnP.services {
            switch (request.method, path) {
            case ("GET", "/\(service.path)/scpd.xml"):
                return HTTPResponse.make(body: UPnP.scpd(for: service))
            case ("SUBSCRIBE", "/\(service.path)/event"):
                // Events are not sent; a subscription id keeps strict control points happy.
                return HTTPResponse.make(contentType: "text/plain", extraHeaders: ["SID": "uuid:\(UUID().uuidString)", "TIMEOUT": "Second-1800"])
            case ("UNSUBSCRIBE", "/\(service.path)/event"):
                return HTTPResponse.make(contentType: "text/plain")
            case ("POST", "/\(service.path)/control"):
                guard let action = SOAPAction(soapActionHeader: request.header("SOAPACTION"), body: request.body) else { break }
                return control(action, service: service)
            default:
                continue
            }
        }
        return HTTPResponse.make(status: "404 Not Found", contentType: "text/plain")
    }

    private func control(_ action: SOAPAction, service: UPnP.Service) -> Data {
        let ok = { (values: [(String, String)]) in
            HTTPResponse.make(body: UPnP.soapResponse(action: action.name, serviceType: service.type, values: values))
        }
        switch action.name {
        case "SetAVTransportURI":
            guard let uri = action.arguments["CurrentURI"], let url = URL(string: uri),
                  let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
                return HTTPResponse.make(status: "500 Internal Server Error", body: UPnP.soapFault(code: 714, description: "Illegal MIME-type"))
            }
            currentURI = uri
            currentMetadata = action.arguments["CurrentURIMetaData"] ?? ""
            castTitle = XML.didlTitle(currentMetadata) ?? url.lastPathComponent
            playback?.playCast(url, title: castTitle ?? friendlyName)
            return ok([])
        case "Play":
            playback?.resumeCast()
            return ok([])
        case "Pause":
            playback?.pauseCast()
            return ok([])
        case "Stop":
            playback?.stopCast()
            return ok([])
        case "Seek":
            if let seconds = action.arguments["Target"].flatMap(UPnP.seconds) { playback?.seekCast(to: seconds) }
            return ok([])
        case "GetTransportInfo":
            return ok([("CurrentTransportState", playback?.castState ?? "NO_MEDIA_PRESENT"),
                       ("CurrentTransportStatus", "OK"), ("CurrentSpeed", "1")])
        case "GetPositionInfo":
            let duration = UPnP.time(playback?.castDuration ?? 0), position = UPnP.time(playback?.castPosition ?? 0)
            return ok([("Track", "1"), ("TrackDuration", duration), ("TrackMetaData", currentMetadata), ("TrackURI", currentURI),
                       ("RelTime", position), ("AbsTime", position), ("RelCount", "2147483647"), ("AbsCount", "2147483647")])
        case "GetMediaInfo":
            return ok([("NrTracks", currentURI.isEmpty ? "0" : "1"), ("MediaDuration", UPnP.time(playback?.castDuration ?? 0)),
                       ("CurrentURI", currentURI), ("CurrentURIMetaData", currentMetadata), ("NextURI", ""),
                       ("NextURIMetaData", ""), ("PlayMedium", "NETWORK"), ("RecordMedium", "NOT_IMPLEMENTED"),
                       ("WriteStatus", "NOT_IMPLEMENTED")])
        case "GetVolume":
            return ok([("CurrentVolume", "100")])
        case "GetMute":
            return ok([("CurrentMute", "0")])
        case "SetVolume", "SetMute":
            return ok([]) // the phone's volume buttons own the volume
        case "GetProtocolInfo":
            let sink: String = ["video/mp4", "video/quicktime", "video/x-m4v", "application/vnd.apple.mpegurl", "application/x-mpegURL",
                        "video/mp2t", "audio/mpeg", "audio/mp4", "*"].map { "http-get:*:\($0):*" }.joined(separator: ",")
            return ok([("Source", ""), ("Sink", sink)])
        case "GetCurrentConnectionIDs":
            return ok([("ConnectionIDs", "0")])
        case "GetCurrentConnectionInfo":
            return ok([("RcsID", "0"), ("AVTransportID", "0"), ("ProtocolInfo", ""), ("PeerConnectionManager", ""),
                       ("PeerConnectionID", "-1"), ("Direction", "Input"), ("Status", "OK")])
        default:
            return HTTPResponse.make(status: "500 Internal Server Error", body: UPnP.soapFault(code: 401, description: "Invalid Action"))
        }
    }

    // MARK: - Helpers

    nonisolated static func storedUUID() -> String {
        let key = "TorpidoRendererUUID"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let fresh = UUID().uuidString.lowercased()
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    /// The iPhone's IPv4 address on Wi-Fi (en0), which other devices reach.
    nonisolated static func wifiAddress() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard let addr = entry.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
                  String(cString: entry.ifa_name) == "en0" else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: host)
            }
        }
        return nil
    }
}

/// Plays silence (mixed with other apps, at zero volume) so iOS keeps Torpido
/// running in the background while the receiver is on.
final class SilentAudioKeepAlive {
    private var player: AVAudioPlayer?

    func start() {
        guard player == nil else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(data: Self.silentWAV())
        player?.numberOfLoops = -1
        player?.volume = 0
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    /// One second of 8 kHz mono 16-bit silence as a WAV file.
    private static func silentWAV() -> Data {
        let sampleRate: UInt32 = 8_000, samples = sampleRate
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + samples * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(sampleRate); append(sampleRate * 2); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(samples * 2))
        data.append(Data(count: Int(samples * 2)))
        return data
    }
}
