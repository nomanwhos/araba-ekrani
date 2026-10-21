import SwiftUI

extension View {
    /// Docks the mini player above the tab bar while something plays.
    func miniPlayerInset() -> some View {
        modifier(MiniPlayerInset())
    }

    /// Long-press menu to add or remove a channel from favourites.
    func favoriteContextMenu(for channel: Channel, isFavorite: Bool) -> some View {
        contextMenu {
            Button {
                try? FavoritesStore(database: .shared).toggle(channel)
            } label: {
                Label(isFavorite ? "Favorilerden çıkar" : "Favorilere ekle", systemImage: isFavorite ? "star.slash" : "star")
            }
        }
    }
}

private struct MiniPlayerInset: ViewModifier {
    private let player = PlayerController.shared

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if player.showsMiniPlayer, let item = player.nowPlaying {
                MiniPlayerBar(title: item.title, subtitle: item.serverItem?.source.name, isPlaying: player.isPlaying,
                              togglePlayback: { player.togglePlayback() },
                              expand: { player.isFullScreen = true })
                    .padding(.bottom, Theme.Space.s8)
            }
        }
    }
}
