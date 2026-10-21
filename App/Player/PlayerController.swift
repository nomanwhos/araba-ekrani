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

/// Owns the one AVPlayer: what is playing, whether the full player is open,
/// and saving the resume position. The mini player and the full player both
/// read from here, so playback survives closing the full screen.
@MainActor
@Observable
final class PlayerController {
    static let shared = PlayerController(database: .shared)

    private static let saveInterval = CMTime(seconds: 10, preferredTimescale: 1)

    private(set) var nowPlaying: Channel?
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
        failure = nil
        saveCurrentPosition()
        guard let url = try? database.reader.read({ try LibraryQueries.firstStreamURL(for: channel, $0) }) else {
            player.replaceCurrentItem(with: nil)
            nowPlaying = channel
            isFullScreen = true
            failure = "Bu kanalın oynatılabilir bir adresi yok."
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        statusObservation = item.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in self?.failure = "Bu yayın açılmadı. Kaynak kapalı olabilir ya da biçimi desteklenmiyor." }
        }
        player.replaceCurrentItem(with: item)
        nowPlaying = channel
        isFullScreen = true
        startSavingPosition()

        if let resume = try? PlaybackPositionStore(database: database).resumePosition(for: channel) {
            player.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
        }
        player.play()
    }

    func togglePlayback() {
        isPlaying ? player.pause() : player.play()
    }

    func closeFullScreen() {
        isFullScreen = false
        saveCurrentPosition()
    }

    func stop() {
        saveCurrentPosition()
        player.pause()
        player.replaceCurrentItem(with: nil)
        nowPlaying = nil
        isFullScreen = false
    }

    private func startSavingPosition() {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = player.addPeriodicTimeObserver(forInterval: Self.saveInterval, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveCurrentPosition() }
        }
    }

    /// Live streams report an indefinite duration and are saved without one,
    /// so they always start live.
    private func saveCurrentPosition() {
        guard let channel = nowPlaying, let item = player.currentItem else { return }
        let position = item.currentTime().seconds
        guard position.isFinite else { return }
        let duration = item.duration.seconds
        try? PlaybackPositionStore(database: database)
            .save(channel: channel, position: position, duration: duration.isFinite ? duration : nil)
    }
}
