import SwiftUI

/// S01b: every channel in one group, including ones the health check hid from Home.
struct GroupView: View {
    let group: ChannelGroup

    @State private var channels: [Channel]?
    @State private var favorites: Set<String> = []
    private let player = PlayerController.shared

    var body: some View {
        Group {
            if let channels {
                List(channels) { channel in
                    let isFavorite = favorites.contains(channel.itemKey)
                    Button {
                        player.play(channel)
                    } label: {
                        ChannelRow(name: channel.name, logoURL: channel.logoURL, health: channel.displayHealth,
                                   isFavorite: isFavorite, isPlaying: player.nowPlaying?.channel?.id == channel.id)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.surface)
                    .swipeActions(edge: .leading) {
                        Button {
                            try? FavoritesStore(database: .shared).toggle(channel)
                        } label: {
                            Label(isFavorite ? "Çıkar" : "Favori", systemImage: isFavorite ? "star.slash" : "star")
                        }
                        .tint(Theme.accent)
                    }
                    .favoriteContextMenu(for: channel, isFavorite: isFavorite)
                }
                .nightGround()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg)
            }
        }
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerInset()
        .task {
            let groupID = group.id
            do {
                for try await value in AppDatabase.shared.observe({ try LibraryQueries.channels(in: groupID, $0) }) {
                    channels = value
                }
            } catch {
                channels = []
            }
        }
        .task {
            do {
                for try await keys in AppDatabase.shared.observe(LibraryQueries.favoriteKeys) { favorites = keys }
            } catch {
                favorites = []
            }
        }
    }
}
