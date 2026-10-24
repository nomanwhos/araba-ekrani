import CarPlay
import CoreMedia

/// Runs when the iPhone is connected to CarPlay.
///
/// Torpido has the CarPlay Video App entitlement (com.apple.developer.carplay-video,
/// granted 2026-10-23). Video apps get templates, not a window: the car shows
/// lists of favourite channels and imported videos, and picking one plays it in
/// the shared player, which iOS shows on the car screen while the car is parked.
/// Cars without video support hide video apps; the status row below says which
/// case a car is in.
///
/// The window variant further down is the navigation-entitlement path
/// (com.apple.developer.carplay-maps) for mirroring, kept for if that is ever granted.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSessionConfigurationDelegate {
    private static let maxListItems = 100

    private var interfaceController: CPInterfaceController?
    private var sessionConfiguration: CPSessionConfiguration?
    private var fillObserver: NSObjectProtocol?

    // MARK: - Video app (templates)

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        sessionConfiguration = CPSessionConfiguration(delegate: self)
        MirrorState.shared.isCarConnected = true
        interfaceController.setRootTemplate(makeRoot(), animated: false, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        sessionConfiguration = nil
        MirrorState.shared.isCarConnected = false
    }

    nonisolated func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration,
                              limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface) {}

    private var carSupportsVideo: Bool {
        guard #available(iOS 26.4, *) else { return false }
        return sessionConfiguration?.supportsVideoPlayback ?? false
    }

    private func makeRoot() -> CPTemplate {
        guard carSupportsVideo else {
            let item = CPListItem(text: String(localized: "Bu araç CarPlay'de video oynatmayı desteklemiyor"),
                                  detailText: String(localized: "Torpido'yu telefonda kullanmaya devam edebilirsiniz."))
            let list = CPListTemplate(title: "Torpido", sections: [CPListSection(items: [item])])
            return list
        }
        let favorites = CPListTemplate(title: String(localized: "Favoriler"), sections: [CPListSection(items: favoriteItems())])
        favorites.tabImage = UIImage(systemName: "star.fill")
        favorites.emptyViewTitleVariants = [String(localized: "Favori kanal yok")]
        favorites.emptyViewSubtitleVariants = [String(localized: "Telefonda bir kanalın yıldızına dokunun.")]

        let videos = CPListTemplate(title: String(localized: "Videolar"), sections: [CPListSection(items: videoItems())])
        videos.tabImage = UIImage(systemName: "film")
        videos.emptyViewTitleVariants = [String(localized: "Video yok")]
        videos.emptyViewSubtitleVariants = [String(localized: "Telefonda Favoriler › Videolar'dan içe aktarın.")]

        return CPTabBarTemplate(templates: [favorites, videos])
    }

    private func favoriteItems() -> [CPListItem] {
        let channels = (try? AppDatabase.shared.reader.read { try LibraryQueries.favoriteChannels($0) }) ?? []
        return channels.prefix(Self.maxListItems).map { channel in
            makeItem(title: channel.name, detail: nil) { PlayerController.shared.play(channel) }
        }
    }

    private func videoItems() -> [CPListItem] {
        let videos = (try? AppDatabase.shared.reader.read { try LibraryQueries.localVideos($0) }) ?? []
        return videos.prefix(Self.maxListItems).map { video in
            makeItem(title: video.displayName, detail: nil) { PlayerController.shared.play(video) }
        }
    }

    private func makeItem(title: String, detail: String?, play: @escaping @MainActor () -> Void) -> CPListItem {
        let item = CPListItem(text: title, detailText: detail)
        if #available(iOS 26.4, *) {
            // Tells CarPlay this row starts video, so the car switches to the video view.
            item.playbackConfiguration = CPPlaybackConfiguration(
                preferredPresentation: .video, playbackAction: .play, elapsedTime: .zero, duration: .zero)
        }
        item.handler = { _, completion in
            MainActor.assumeIsolated { play() }
            completion()
        }
        return item
    }

    // MARK: - Navigation app (window), for mirroring

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
        return CPBarButton(title: fills ? String(localized: "Sığdır") : String(localized: "Doldur")) { _ in
            MainActor.assumeIsolated { MirrorState.shared.fillsCarScreen.toggle() }
        }
    }
}
