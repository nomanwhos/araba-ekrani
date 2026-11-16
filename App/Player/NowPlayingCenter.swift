import AVFoundation
import MediaPlayer

/// What the system shows as Now Playing: the CarPlay Now Playing screen, the
/// Lock Screen and Control Center, plus their play/pause buttons.
@MainActor
enum NowPlayingCenter {
    static func connect(_ controller: PlayerController) {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak controller] _ in
            MainActor.assumeIsolated { controller?.player.play() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak controller] _ in
            MainActor.assumeIsolated { controller?.player.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak controller] _ in
            MainActor.assumeIsolated { controller?.togglePlayback() }
            return .success
        }
    }

    static func update(title: String, isLive: Bool, player: AVPlayer) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Torpido",
            MPNowPlayingInfoPropertyIsLiveStream: isLive,
            MPNowPlayingInfoPropertyPlaybackRate: Double(player.rate),
        ]
        let elapsed = player.currentTime().seconds
        if elapsed.isFinite { info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed }
        if let duration = player.currentItem?.duration.seconds, duration.isFinite, !isLive {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    static func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
