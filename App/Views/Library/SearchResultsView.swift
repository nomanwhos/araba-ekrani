import SwiftUI

/// S18: channels matching the search text, across every source.
struct SearchResultsView: View {
    /// Waits this long after the last keystroke before querying.
    private static let debounce: Duration = .milliseconds(250)

    let query: String

    @State private var results: [Channel]?
    @State private var favorites: Set<String> = []
    private let player = PlayerController.shared

    var body: some View {
        Group {
            switch results {
            case nil:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let results? where results.isEmpty:
                EmptyState(symbol: "magnifyingglass", title: "Sonuç yok",
                           message: "“\(query)” adında kanal bulunamadı. Daha kısa ya da farklı bir kelime deneyin.")
                    .frame(maxHeight: .infinity)
            case let results?:
                List(results) { channel in
                    Button {
                        SearchHistoryStore(database: .shared).recordIgnoringErrors(query)
                        player.play(channel)
                    } label: {
                        ChannelRow(name: channel.name, logoURL: channel.logoURL, health: channel.displayHealth,
                                   isFavorite: favorites.contains(channel.itemKey),
                                   isPlaying: player.nowPlaying?.channel?.id == channel.id)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.surface)
                    .favoriteContextMenu(for: channel, isFavorite: favorites.contains(channel.itemKey))
                }
                .nightGround()
            }
        }
        .task(id: query) {
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            let text = query
            results = (try? await AppDatabase.shared.reader.read { try LibraryQueries.search(text, $0) }) ?? []
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

extension SearchHistoryStore {
    /// History is a convenience; failing to save it must never block playback.
    func recordIgnoringErrors(_ text: String) {
        try? record(text)
    }
}
