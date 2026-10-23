import SwiftUI

/// S02: favourite channels, and the videos kept on the phone for offline viewing (S19).
struct FavoritesView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case channels = "Kanallar", videos = "Videolar"
        var id: String { rawValue }
    }

    @State private var segment = Segment.channels
    @State private var channels: [Channel]?
    private let player = PlayerController.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Bölüm", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Space.s16)
                .padding(.vertical, Theme.Space.s8)

                switch segment {
                case .channels: favoriteChannels
                case .videos: LocalVideosView()
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

    @ViewBuilder
    private var favoriteChannels: some View {
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
}
