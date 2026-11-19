import Observation
import SwiftUI

/// Whether Car mode is open. RootView presents it, so the shared player can sit on top of it.
@MainActor
@Observable
final class CarModeState {
    static let shared = CarModeState()
    var isOpen = false
}

/// Car mode: a big-target screen for a phone in a dashboard mount, for passengers
/// or a parked car. Tabs across the top (Home, Favourites, Cast, Browser), large
/// logos, one tap to play. Written as a self-contained screen so it can be shown
/// on another display later without changes.
struct CarModeView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case home, favorites, cast, browser
        var id: String { rawValue }
    }

    @State private var tab: Tab = .home
    @State private var favorites: Set<String> = []
    @Bindable private var player = PlayerController.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch tab {
                case .home: CarHomeTab(favorites: favorites)
                case .favorites: CarFavoritesTab()
                case .cast: CarCastTab()
                case .browser: NavigationStack { BrowserView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $player.isFullScreen) {
            PlayerScreen(controller: player,
                         isFavorite: player.nowPlaying?.channel.map { favorites.contains($0.itemKey) },
                         toggleFavorite: {
                             if let channel = player.nowPlaying?.channel { try? FavoritesStore(database: .shared).toggle(channel) }
                         })
        }
        .task {
            do {
                for try await keys in AppDatabase.shared.observe(LibraryQueries.favoriteKeys) { favorites = keys }
            } catch {
                favorites = []
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: Theme.Space.s12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .frame(width: Theme.Size.tapMin, height: Theme.Size.tapMin)
            }
            .accessibilityLabel("Araba modundan çık")

            Spacer(minLength: 0)
            HStack(spacing: Theme.Space.s4) {
                ForEach(Tab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        Text(title(for: item))
                            .font(.headline)
                            .foregroundStyle(tab == item ? Theme.onAccent : Theme.text)
                            .padding(.horizontal, Theme.Space.s16)
                            .frame(minHeight: Theme.Size.tapMin)
                            .background(tab == item ? Theme.accent : .clear, in: Capsule())
                    }
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
                }
            }
            .padding(Theme.Space.s4)
            .background(Theme.surface, in: Capsule())
            Spacer(minLength: 0)

            AirPlayButton()
                .frame(width: Theme.Size.tapMin, height: Theme.Size.tapMin)
            MiniNowPlaying()
        }
        .padding(.horizontal, Theme.Space.s16)
        .padding(.vertical, Theme.Space.s8)
    }

    private func title(for tab: Tab) -> LocalizedStringKey {
        switch tab {
        case .home: "Ana Sayfa"
        case .favorites: "Favoriler"
        case .cast: "Cast"
        case .browser: "Tarayıcı"
        }
    }
}

/// What is playing, with play/pause, in the corner of the top bar.
private struct MiniNowPlaying: View {
    @Bindable private var player = PlayerController.shared

    var body: some View {
        if let nowPlaying = player.nowPlaying {
            Button {
                player.togglePlayback()
            } label: {
                HStack(spacing: Theme.Space.s8) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    Text(CarPlayText.cleanName(nowPlaying.title)).lineLimit(1)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, Theme.Space.s12)
                .frame(maxWidth: 220, minHeight: Theme.Size.tapMin)
                .background(Theme.surface, in: Capsule())
            }
            .accessibilityLabel(player.isPlaying ? "Duraklat" : "Oynat")
            .accessibilityValue(nowPlaying.title)
        } else {
            Color.clear.frame(width: Theme.Size.tapMin, height: Theme.Size.tapMin)
        }
    }
}
