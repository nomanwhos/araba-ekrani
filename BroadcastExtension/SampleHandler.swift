import CoreMedia
import ImageIO
import Network
import QuartzCore
import ReplayKit

/// Captures the whole iPhone screen and streams it to the Torpido app,
/// which draws it on the CarPlay display.
///
/// Runs in its own process with a ~50 MB memory ceiling. A full-screen buffer
/// is ~10 MB, so frames are dropped before they are queued: at most one frame
/// is ever being encoded or sent.
final class SampleHandler: RPBroadcastSampleHandler {
    private static let minFrameInterval: CFTimeInterval = 1.0 / 30.0

    private let queue = DispatchQueue(label: "torpido.broadcast.send")
    private let encoder = FrameEncoder()
    private let lock = NSLock()

    // Guarded by `lock`: read on ReplayKit's thread, written on `queue`.
    private var isReady = false
    private var isBusy = false
    private var didFinish = false
    private var lastAcceptedAt: CFTimeInterval = 0

    // Touched only on `queue`.
    private var connection: NWConnection?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        let connection = NWConnection(
            host: NWEndpoint.Host(MirrorLink.host),
            port: NWEndpoint.Port(rawValue: MirrorLink.port)!,
            using: .tcp
        )
        connection.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }
        queue.async {
            self.connection = connection
            connection.start(queue: self.queue)
        }
    }

    override func broadcastFinished() {
        withLock { didFinish = true; isReady = false }
        queue.async {
            self.connection?.cancel()
            self.connection = nil
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, acceptFrame() else { return }
        queue.async { [weak self] in
            self?.send(sampleBuffer)
        }
    }

    /// Claims the single in-flight slot if the stream is ready and a frame is due.
    private func acceptFrame() -> Bool {
        let now = CACurrentMediaTime()
        return withLock {
            guard isReady, !isBusy, now - lastAcceptedAt >= Self.minFrameInterval else { return false }
            isBusy = true
            lastAcceptedAt = now
            return true
        }
    }

    private func send(_ sampleBuffer: CMSampleBuffer) {
        guard let connection,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let jpeg = encoder.jpeg(from: pixelBuffer, orientation: Self.orientation(of: sampleBuffer))
        else {
            withLock { isBusy = false }
            return
        }
        connection.send(content: MirrorLink.frame(jpeg), completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            self.withLock { self.isBusy = false }
            if error != nil {
                self.finish()
            }
        })
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            withLock { isReady = true }
        case .waiting, .failed:
            // Connection refused: the app is not running to receive frames.
            finish()
        case .cancelled:
            withLock { isReady = false }
        default:
            break
        }
    }

    /// Ends the broadcast once with a message the system shows the user.
    private func finish() {
        let shouldFinish = withLock { () -> Bool in
            isReady = false
            guard !didFinish else { return false }
            didFinish = true
            return true
        }
        if shouldFinish {
            finishBroadcastWithError(Self.appNotReachableError)
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private static func orientation(of sampleBuffer: CMSampleBuffer) -> CGImagePropertyOrientation {
        let raw = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber
        return raw.flatMap { CGImagePropertyOrientation(rawValue: $0.uint32Value) } ?? .up
    }

    private static let appNotReachableError = NSError(
        domain: "Torpido",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Torpido'ya ulaşılamadı. Torpido'yu açıp tekrar deneyin."]
    )
}
