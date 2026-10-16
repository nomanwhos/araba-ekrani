import SwiftUI

@main
struct TorpidoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MirrorServer.shared.start()
        #if DEBUG
        DebugLaunchState.apply()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { _, phase in
            // The listener may have been torn down while suspended.
            if phase == .active { MirrorServer.shared.start() }
        }
    }
}
