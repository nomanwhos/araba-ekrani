import SwiftUI

@main
struct TorpidoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MirrorServer.shared.start()
        DLNARenderer.shared.restore()
        #if DEBUG
        DebugLaunchState.apply()
        DebugLaunchState.resetIfRequested()
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
            guard phase == .active else { return }
            MirrorServer.shared.start()
            // Rate-limited inside; usually checks nothing on a quick return to the app.
            Task.detached(priority: .background) { await HealthChecker(database: .shared).run() }
        }
    }
}
