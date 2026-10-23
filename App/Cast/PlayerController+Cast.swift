import AVFoundation

/// DLNA commands drive the same player as everything else, so a cast video
/// shows in the full player, the mini player and on the car screen.
extension PlayerController: CastPlayback {
    func playCast(_ url: URL, title: String) { play(remote: url, title: title) }
    func resumeCast() { player.play() }
    func pauseCast() { player.pause() }
    func stopCast() { stop() }

    func seekCast(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    var castState: String {
        guard nowPlaying != nil, player.currentItem != nil else { return "STOPPED" }
        return isPlaying ? "PLAYING" : "PAUSED_PLAYBACK"
    }

    var castPosition: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    var castDuration: Double {
        let seconds = player.currentItem?.duration.seconds ?? 0
        return seconds.isFinite ? seconds : 0
    }
}
