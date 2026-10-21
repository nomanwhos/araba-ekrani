#if DEBUG
import Foundation

/// Lets CI screenshots show each state without a car or a live broadcast:
/// `xcrun simctl launch <udid> <bundle> -TorpidoStage live -TorpidoTab settings`
enum DebugLaunchState {
    @MainActor
    static func apply() {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "TorpidoStage") {
        case "ready":
            MirrorState.shared.isCarConnected = true
        case "live":
            MirrorState.shared.isCarConnected = true
            MirrorState.shared.isStreaming = true
            MirrorState.shared.framesPerSecond = 30
        default:
            break
        }
    }

    static var showsCatalog: Bool {
        UserDefaults.standard.bool(forKey: "TorpidoCatalog")
    }

    static var initialTab: RootView.TabID {
        UserDefaults.standard.string(forKey: "TorpidoTab") == "settings" ? .settings : .perde
    }
}
#endif
