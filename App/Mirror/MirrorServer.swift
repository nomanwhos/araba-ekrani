import CoreGraphics
import ImageIO
import Network

/// Receives the frame stream from the broadcast extension over loopback and
/// hands decoded images to whatever display is attached (the CarPlay window).
final class MirrorServer {
    static let shared = MirrorServer()

    private static let receiveChunkBytes = 1 << 20
    private static let restartDelay: DispatchTimeInterval = .seconds(1)

    private let queue = DispatchQueue(label: "torpido.mirror.receive")
    private var listener: NWListener?
    private var connection: NWConnection?
    private var decoder = FrameDecoder()
    private var framesThisSecond = 0
    private var fpsTimer: DispatchSourceTimer?

    /// Set on the main queue; called there with each decoded frame, or nil when the stream ends.
    var onFrame: ((CGImage?) -> Void)?

    private init() {}

    func start() {
        queue.async { [weak self] in
            self?.startListener()
        }
    }

    private func startListener() {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .loopback
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: MirrorLink.port)!)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let self, case .failed(let error) = state else { return }
                // iOS can tear the listener down while the app is suspended; rebuild it.
                listener?.cancel()
                self.listener = nil
                self.publish { $0.serverError = "Alıcı başlatılamadı: \(error.localizedDescription)" }
                self.queue.asyncAfter(deadline: .now() + Self.restartDelay) { [weak self] in
                    self?.startListener()
                }
            }
            listener.start(queue: queue)
            self.listener = listener
            publish { $0.serverError = nil }
        } catch {
            publish { $0.serverError = "Alıcı başlatılamadı: \(error.localizedDescription)" }
        }
    }

    /// Only one broadcast at a time; a new one replaces the old.
    private func accept(_ newConnection: NWConnection) {
        connection?.cancel()
        connection = newConnection
        decoder = FrameDecoder()
        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let self, let newConnection else { return }
            switch state {
            case .ready:
                self.setStreaming(true)
                self.receive(on: newConnection)
            case .failed, .cancelled:
                self.endStream(newConnection)
            default:
                break
            }
        }
        newConnection.start(queue: queue)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.receiveChunkBytes) { [weak self] data, _, isComplete, error in
            guard let self, connection === self.connection else { return }
            if let data, !data.isEmpty {
                do {
                    try self.decoder.append(data).forEach(self.display)
                } catch {
                    connection.cancel()
                    return
                }
            }
            if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receive(on: connection)
            }
        }
    }

    private func display(_ jpeg: Data) {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return }
        framesThisSecond += 1
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(image)
        }
    }

    private func endStream(_ ended: NWConnection) {
        guard ended === connection else { return }
        connection = nil
        setStreaming(false)
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(nil)
        }
    }

    private func setStreaming(_ streaming: Bool) {
        fpsTimer?.cancel()
        fpsTimer = nil
        framesThisSecond = 0
        if streaming {
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 1, repeating: 1)
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                let fps = self.framesThisSecond
                self.framesThisSecond = 0
                self.publish { $0.framesPerSecond = fps }
            }
            timer.resume()
            fpsTimer = timer
        }
        publish {
            $0.isStreaming = streaming
            $0.framesPerSecond = 0
        }
    }

    private func publish(_ update: @escaping @MainActor (MirrorState) -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { update(MirrorState.shared) }
        }
    }
}
