import Foundation
import Observation

/// What the phone UI and the CarPlay screen both read.
@MainActor
@Observable
final class MirrorState {
    static let shared = MirrorState()

    private static let fillKey = "fillCarScreen"
    static let fillDidChange = Notification.Name("TorpidoFillDidChange")

    var isCarConnected = false
    var isStreaming = false
    var framesPerSecond = 0
    var serverError: String?

    /// Fill the car display (crops edges) instead of fitting with black bars.
    var fillsCarScreen: Bool = UserDefaults.standard.bool(forKey: MirrorState.fillKey) {
        didSet {
            UserDefaults.standard.set(fillsCarScreen, forKey: Self.fillKey)
            NotificationCenter.default.post(name: Self.fillDidChange, object: nil)
        }
    }

    private init() {}
}
