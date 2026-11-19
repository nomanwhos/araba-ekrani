import CarPlay
import CoreMedia

/// Runs when the iPhone is connected to CarPlay.
///
/// Torpido has the CarPlay Audio App entitlement (com.apple.developer.carplay-audio,
/// granted 2026-11-15). Audio apps show in every CarPlay car: tabs list favourite
/// channels, recently played items and imported videos, and picking one plays it
/// in the shared player and opens the Now Playing screen. Since iOS 26.4 the audio
/// entitlement also covers mixed audio and video, so in cars that support video the
/// rows ask for video presentation; elsewhere they play as audio.
///
/// The window variant further down is the navigation-entitlement path
/// (com.apple.developer.carplay-maps) for mirroring. Apple declined it on 2026-11-13;
/// it stays so the mirroring code keeps compiling and could be reused.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSessionConfigurationDelegate,
    CPTabBarTemplateDelegate {
    private static let maxListItems = 100
    private static let maxLogosPerRow = 12

    private var interfaceController: CPInterfaceController?
    private var sessionConfiguration: CPSessionConfiguration?
    private var fillObserver: NSObjectProtocol?
    private var lists: [(template: CPListTemplate, items: () -> [any CPListTemplateItem])] = []

    // MARK: - Audio app (templates)

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
        lists = []
        MirrorState.shared.isCarConnected = false
    }

    nonisolated func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration,
                                          limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface) {}

    /// Favourites or videos may have changed on the phone; refresh the tab being opened.
    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        guard let list = lists.first(where: { $0.template === selectedTemplate }) else { return }
        list.template.updateSections([CPListSection(items: list.items())])
    }

    private var carSupportsVideo: Bool {
        guard #available(iOS 26.4, *) else { return false }
        return sessionConfiguration?.supportsVideoPlayback ?? false
    }

    private func makeRoot() -> CPTemplate {
        let home = makeList(title: String(localized: "Ana Sayfa"), symbol: "house.fill",
                            emptyTitle: String(localized: "Henüz kanal yok"),
                            emptySubtitle: String(localized: "Telefonda Ayarlar › Kaynaklar'dan bir liste ekleyin."),
                            items: { [weak self] in self?.homeItems() ?? [] })
        let favorites = makeList(title: String(localized: "Favoriler"), symbol: "star.fill",
                                 emptyTitle: String(localized: "Favori kanal yok"),
                                 emptySubtitle: String(localized: "Telefonda bir kanalın yıldızına dokunun."),
                                 items: { [weak self] in self?.favoriteItems() ?? [] })
        let recent = makeList(title: String(localized: "Son izlenenler"), symbol: "clock.arrow.circlepath",
                              emptyTitle: String(localized: "Henüz bir şey oynatılmadı"),
                              emptySubtitle: String(localized: "Telefonda ya da burada bir kanal açın."),
                              items: { [weak self] in self?.recentItems() ?? [] })
        let videos = makeList(title: String(localized: "Videolar"), symbol: "film",
                              emptyTitle: String(localized: "Video yok"),
                              emptySubtitle: String(localized: "Telefonda Favoriler › Videolar'dan içe aktarın."),
                              items: { [weak self] in self?.videoItems() ?? [] })
        let tabs = CPTabBarTemplate(templates: [home, favorites, recent, videos])
        tabs.delegate = self
        return tabs
    }

    private func makeList(title: String, symbol: String, emptyTitle: String, emptySubtitle: String,
                          items: @escaping () -> [any CPListTemplateItem]) -> CPListTemplate {
        let list = CPListTemplate(title: title, sections: [CPListSection(items: items())])
        list.tabImage = UIImage(systemName: symbol)
        list.emptyViewTitleVariants = [emptyTitle]
        list.emptyViewSubtitleVariants = [emptySubtitle]
        lists.append((list, items))
        return list
    }

    /// One row per group: its name and a strip of channel logos. Tapping a logo plays
    /// that channel; tapping the row opens the whole group.
    private func homeItems() -> [any CPListTemplateItem] {
        let sections = (try? AppDatabase.shared.reader.read { try LibraryQueries.homeSections($0) }) ?? []
        return sections.map { section in
            let channels = Array(section.channels.prefix(Self.maxLogosPerRow))
            let artwork = RowArtwork(count: channels.count)
            let title = [section.group.title, "(\(section.total))"].joined(separator: " ")
            let row = CPListImageRowItem(text: title, images: artwork.images)
            row.listImageRowHandler = { [weak self] _, index, completion in
                MainActor.assumeIsolated {
                    if channels.indices.contains(index) {
                        PlayerController.shared.play(channels[index])
                        self?.showNowPlaying()
                    }
                }
                completion()
            }
            row.handler = { [weak self] _, completion in
                MainActor.assumeIsolated { self?.showGroup(section.group) }
                completion()
            }
            for (index, channel) in channels.enumerated() {
                LogoCache.shared.image(for: channel.logoURL, size: CPListImageRowItem.maximumImageSize) { [weak row] image in
                    artwork.images[index] = image
                    row?.update(artwork.images)
                }
            }
            return row
        }
    }

    private func showGroup(_ group: ChannelGroup) {
        let channels = (try? AppDatabase.shared.reader.read { try LibraryQueries.channels(in: group.id, $0) }) ?? []
        let items = channels.filter { $0.health != .down }.prefix(Self.maxListItems).map(item(for:))
        let list = CPListTemplate(title: group.title, sections: [CPListSection(items: Array(items))])
        interfaceController?.pushTemplate(list, animated: true, completion: nil)
    }

    private func favoriteItems() -> [CPListItem] {
        let channels = (try? AppDatabase.shared.reader.read { try LibraryQueries.favoriteChannels($0) }) ?? []
        return channels.prefix(Self.maxListItems).map(item(for:))
    }

    private func recentItems() -> [CPListItem] {
        let recent = (try? AppDatabase.shared.reader.read { try LibraryQueries.recentItems(limit: Self.maxListItems, $0) }) ?? []
        return recent.map { entry in
            switch entry {
            case .channel(let channel): item(for: channel)
            case .video(let video): item(for: video)
            }
        }
    }

    private func videoItems() -> [CPListItem] {
        let videos = (try? AppDatabase.shared.reader.read { try LibraryQueries.localVideos($0) }) ?? []
        return videos.prefix(Self.maxListItems).map(item(for:))
    }

    private func item(for channel: Channel) -> CPListItem {
        let item = makeItem(title: CarPlayText.cleanName(channel.name), playingTitle: channel.name) {
            PlayerController.shared.play(channel)
        }
        item.setImage(LogoCache.placeholder)
        LogoCache.shared.image(for: channel.logoURL, size: CPListItem.maximumImageSize) { [weak item] image in
            item?.setImage(image)
        }
        return item
    }

    private func item(for video: LocalVideo) -> CPListItem {
        makeItem(title: video.displayName, playingTitle: video.displayName) { PlayerController.shared.play(video) }
    }

    private func makeItem(title: String, playingTitle: String, play: @escaping @MainActor () -> Void) -> CPListItem {
        let item = CPListItem(text: title, detailText: nil)
        item.isPlaying = PlayerController.shared.nowPlaying?.title == playingTitle
        if #available(iOS 26.4, *) {
            // Video where the car supports it; otherwise the system plays the sound only.
            item.playbackConfiguration = CPPlaybackConfiguration(
                preferredPresentation: carSupportsVideo ? .video : .audio,
                playbackAction: .play, elapsedTime: .zero, duration: .zero)
        }
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                play()
                self?.showNowPlaying()
            }
            completion()
        }
        return item
    }

    private func showNowPlaying() {
        guard let interfaceController, interfaceController.topTemplate !== CPNowPlayingTemplate.shared else { return }
        interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
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


/// The logos of one Home row, filled in as they download.
@MainActor
private final class RowArtwork {
    var images: [UIImage]

    init(count: Int) {
        images = Array(repeating: LogoCache.placeholder, count: count)
    }
}
