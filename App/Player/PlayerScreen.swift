import AVKit
import SwiftUI

/// Full-screen playback (S14): the system player plus a close button,
/// the channel name and favourite, and an error message when the stream fails.
struct PlayerScreen: View {
    @Bindable var controller: PlayerController
    /// nil for items that cannot be favourited (media-server items).
    let isFavorite: Bool?
    let toggleFavorite: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            SystemPlayer(player: controller.player, fills: controller.fillsScreen)
                .ignoresSafeArea()

            HStack(spacing: Theme.Space.s8) {
                Button {
                    controller.closeFullScreen()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline)
                        .frame(width: Theme.Size.tapMin, height: Theme.Size.tapMin)
                }
                .accessibilityLabel("Oynatıcıyı küçült")

                Text(controller.nowPlaying?.title ?? "")
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 0)

                Button {
                    controller.fillsScreen.toggle()
                } label: {
                    Image(systemName: controller.fillsScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.headline)
                        .frame(width: Theme.Size.tapMin, height: Theme.Size.tapMin)
                }
                .accessibilityLabel(LocalizedStringKey(controller.fillsScreen ? "Görüntüyü sığdır" : "Görüntüyü ekrana doldur"))

                if let isFavorite {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.headline)
                            .foregroundStyle(isFavorite ? Theme.accent : Theme.text)
                            .frame(width: Theme.Size.tapMin, height: Theme.Size.tapMin)
                    }
                    .accessibilityLabel(LocalizedStringKey(isFavorite ? "Favorilerden çıkar" : "Favorilere ekle"))
                }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, Theme.Space.s8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal, Theme.Space.s12)

            if let failure = controller.failure {
                Label(failure, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                    .padding(Theme.Space.s16)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.perde, style: .continuous))
                    .padding(Theme.Space.s24)
                    .frame(maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}

private struct SystemPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    let fills: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = false
        // Subtitles, audio tracks and speed come from the system controls when the stream has them.
        controller.videoGravity = fills ? .resizeAspectFill : .resizeAspect
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.videoGravity = fills ? .resizeAspectFill : .resizeAspect
        if controller.player !== player { controller.player = player }
    }
}
