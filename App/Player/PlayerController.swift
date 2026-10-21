import AVFoundation
import Foundation
import GRDB
import Observation

extension AppDatabase {
    /// Live values of a query for SwiftUI `.task` loops.
    func observe<T: Sendable>(_ fetch: @escaping @Sendable (Database) throws -> T) -> AsyncValueObservation<T> {
        ValueObservation.tracking(fetch).values(in: reader)
    }
}

/// What is playing: a playlist channel (favourites and local resume) or an
/// item on the owner's Jellyfin server (resume lives on the server).
struct NowPlaying: Equatable {
    struct ServerItem: Equatable {
        var source: Source
        var itemID: String
        var playSessionID: String
    }

    var title: String
    var channel: Channel?
    var serverItem: ServerItem?
}

/// Owns the one AVPlayer: what is playing, whether the full player is open,
/// and saving the resume position. The mini player and the full player both
/// read from here, so playback survives closing the full screen.
@MainActor
@Observable
final class PlayerController {
    static let shared = PlayerController(database: .shared)

    private static let saveInterval = CMTime(seconds: 10, preferredTimescale: 1)

    private(set) var nowPlaying: NowPlaying?
    private(set) var isPlaying = false
    private(set) var failure: String?
    var isFullScreen = false

    let player = AVPlayer()
    private let database: AppDatabase
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?

    var showsMiniPlayer: Bool { nowPlaying != nil && !isFullScreen }

    init(database: AppDatabase) {
        self.database = database
        rateObservation = player.observe(\.timeControlStatus) { [weak self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor in self?.isPlaying = playing }
        }
    }

    func play(_ channel: Channel) {
        let stored = try? database.reader.read { try LibraryQueries.firstStreamURL(for: channel, $0) }
        let url = stored.flatMap { StreamResolver(database: database).playableURL(for: $0, sourceID: channel.sourceId) }
        let resume = try? PlaybackPositionStore(database: database).resumePosition(for: channel)
        start(NowPlaying(title: channel.name, channel: channel), url: url, resume: resume,
              missingMessage: "Bu kanalın oynatılabilir bir adresi yok.")
    }

    /// A movie or episode from the owner's Jellyfin server.
    func play(_ item: JellyfinClient.Item, from source: Source) {
        let sessionID = UUID().uuidString
        let client = SourceStore(database: database).jellyfinClient(for: source)
        let url = client?.playbackURL(itemID: item.id, playSessionID: sessionID)
        let serverItem = NowPlaying.ServerItem(source: source, itemID: item.id, playSessionID: sessionID)
        start(NowPlaying(title: item.displayTitle, serverItem: serverItem), url: url, resume: item.resumeSeconds,
              missingMessage: "Sunucu oturumu bulunamadı. Ayarlar › Kaynaklar'dan sunucuyu yeniden ekleyin.")
        report(.started)
    }

    func togglePlayback() {
        isPlaying ? player.pause() : player.play()
    }

    func closeFullScreen() {
        isFullScreen = false
        saveCurrentPosition()
    }

    func stop() {
        finishCurrent()
        player.replaceCurrentItem(with: nil)
        nowPlaying = nil
        isFullScreen = false
    }

    private func start(_ item: NowPlaying, url: URL?, resume: Double?, missingMessage: String) {
        finishCurrent()
        failure = nil
        nowPlaying = item
        isFullScreen = true
        guard let url else {
            player.replaceCurrentItem(with: nil)
            failure = missingMessage
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let playerItem = AVPlayerItem(url: url)
        statusObservation = playerItem.observe(\.status) { [weak self] playerItem, _ in
            guard playerItem.status == .failed else { return }
            Task { @MainActor in self?.failure = "Bu yayın açılmadı. Kaynak kapalı olabilir ya da biçimi desteklenmiyor." }
        }
        player.replaceCurrentItem(with: playerItem)
        startSavingPosition()
        if let resume {
            player.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
        }
        player.play()
    }

    /// Saves where the outgoing item stopped before something else starts.
    private func finishCurrent() {
        saveCurrentPosition()
        report(.stopped)
        player.pause()
    }

    private func startSavingPosition() {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = player.addPeriodicTimeObserver(forInterval: Self.saveInterval, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveCurrentPosition() }
        }
    }

    /// Channels save locally; live streams report an indefinite duration and are
    /// saved without one, so they always start live. Server items report to the server.
    private func saveCurrentPosition() {
        guard let nowPlaying, let item = player.currentItem else { return }
        let position = item.currentTime().seconds
        guard position.isFinite else { return }
        if let channel = nowPlaying.channel {
            let duration = item.duration.seconds
            try? PlaybackPositionStore(database: database)
                .save(channel: channel, position: position, duration: duration.isFinite ? duration : nil)
        } else {
            report(.progress)
        }
    }

    /// Fire-and-forget: a missed progress report only costs a less exact resume point.
    private func report(_ kind: JellyfinClient.ReportKind) {
        guard let serverItem = nowPlaying?.serverItem,
              let client = SourceStore(database: database).jellyfinClient(for: serverItem.source) else { return }
        let seconds = player.currentItem?.currentTime().seconds ?? 0
        let report = JellyfinClient.PlaybackReport(
            itemID: serverItem.itemID, mediaSourceID: serverItem.itemID, playSessionID: serverItem.playSessionID,
            positionTicks: Int64((seconds.isFinite ? seconds : 0) * Double(JellyfinClient.ticksPerSecond)),
            isPaused: !isPlaying
        )
        Task.detached { try? await client.report(kind, report) }
    }
}
