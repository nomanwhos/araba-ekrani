import SwiftUI

/// S02: favourite channels in the order they were added.
struct FavoritesView: View {
    @State private var channels: [Channel]?
    private let player = PlayerController.shared

    var body: some View {
        NavigationStack {
            Group {
                switch channels {
                case nil:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let channels? where channels.isEmpty:
                    EmptyState(symbol: "star", title: "Favori yok",
                               message: "Bir kanala basılı tutup Favorilere ekle'yi seçin, ya da oynatırken yıldıza dokunun.")
                        .frame(maxHeight: .infinity)
                case let channels?:
                    List(channels) { channel in
                        Button {
                            player.play(channel)
                        } label: {
                            ChannelRow(name: channel.name, logoURL: channel.logoURL, health: channel.displayHealth,
                                       isPlaying: player.nowPlaying?.channel?.id == channel.id)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                        .swipeActions {
                            Button(role: .destructive) {
                                try? FavoritesStore(database: .shared).toggle(channel)
                            } label: {
                                Label("Çıkar", systemImage: "star.slash")
                            }
                        }
                    }
                    .nightGround()
                }
            }
            .background(Theme.bg)
            .navigationTitle("Favoriler")
            .miniPlayerInset()
        }
        .task {
            do {
                for try await value in AppDatabase.shared.observe(LibraryQueries.favoriteChannels) { channels = value }
            } catch {
                channels = []
            }
        }
    }
}
