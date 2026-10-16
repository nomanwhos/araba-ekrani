import CarPlay

/// Runs when the iPhone is connected to CarPlay. Requires the CarPlay
/// navigation entitlement (com.apple.developer.carplay-maps): that is what
/// gives Torpido a CPWindow it may draw into instead of a fixed template.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var fillObserver: NSObjectProtocol?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        let screen = CarScreenViewController()
        window.rootViewController = screen
        MirrorServer.shared.onFrame = { [weak screen] image in
            MainActor.assumeIsolated { screen?.show(image) }
        }
        MirrorServer.shared.start()

        let map = CPMapTemplate()
        map.automaticallyHidesNavigationBar = true
        map.leadingNavigationBarButtons = [makeFillButton(for: map)]
        interfaceController.setRootTemplate(map, animated: false, completion: nil)

        fillObserver = NotificationCenter.default.addObserver(
            forName: MirrorState.fillDidChange, object: nil, queue: .main
        ) { [weak self, weak map] _ in
            guard let self, let map else { return }
            MainActor.assumeIsolated {
                map.leadingNavigationBarButtons = [self.makeFillButton(for: map)]
            }
        }
        MirrorState.shared.isCarConnected = true
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        if let fillObserver {
            NotificationCenter.default.removeObserver(fillObserver)
        }
        fillObserver = nil
        MirrorServer.shared.onFrame = nil
        self.interfaceController = nil
        MirrorState.shared.isCarConnected = false
    }

    /// Lets the passenger switch between fitting and filling the car display.
    private func makeFillButton(for map: CPMapTemplate) -> CPBarButton {
        let fills = MirrorState.shared.fillsCarScreen
        return CPBarButton(title: fills ? "Sığdır" : "Doldur") { _ in
            MainActor.assumeIsolated { MirrorState.shared.fillsCarScreen.toggle() }
        }
    }
}
