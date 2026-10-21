import SwiftUI

@main
struct TorpidoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MirrorServer.shared.start()
        #if DEBUG
        DebugLaunchState.apply()
        DebugLaunchState.seedIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if DebugLaunchState.showsCatalog {
                DesignCatalogView()
            } else {
                RootView()
            }
            #else
            RootView()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // The listener may have been torn down while suspended.
            if phase == .active { MirrorServer.shared.start() }
        }
    }
}
