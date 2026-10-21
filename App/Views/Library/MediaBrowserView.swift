import SwiftUI

/// Where a Jellyfin browse step points: the server's libraries, or the children of one item.
struct MediaRoute: Hashable {
    var source: Source
    var parent: JellyfinClient.Item?
}

/// S16: a Jellyfin server, one level at a time. Libraries, then movies or
/// series, then seasons, then episodes. Folders open, movies and episodes play.
struct MediaBrowserView: View {
    let route: MediaRoute

    private enum Load: Equatable {
        case loading
        case loaded([JellyfinClient.Item])
        case failed(String)
    }

    @State private var load = Load.loading
    private let player = PlayerController.shared

    var body: some View {
        content
            .background(Theme.bg)
            .navigationTitle(route.parent?.name ?? route.source.name)
            .navigationBarTitleDisplayMode(route.parent == nil ? .large : .inline)
            .miniPlayerInset()
            .task(id: route) { await fetch() }
            .refreshable { await fetch() }
    }

    @ViewBuilder
    private var content: some View {
        switch load {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyState(symbol: "exclamationmark.triangle", title: "Sunucu açılmadı", message: message,
                       actionTitle: "Tekrar dene") { Task { await fetch() } }
                .frame(maxHeight: .infinity)
        case .loaded(let items) where items.isEmpty:
            EmptyState(symbol: "film.stack", title: "Burada bir şey yok",
                       message: "Bu klasörde oynatılabilir video bulunamadı.")
                .frame(maxHeight: .infinity)
        case .loaded(let items):
            List(items) { item in
                Group {
                    if item.isPlayable {
                        Button {
                            player.play(item, from: route.source)
                        } label: {
                            MediaRow(item: item, isPlaying: player.nowPlaying?.serverItem?.itemID == item.id)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: MediaRoute(source: route.source, parent: item)) {
                            MediaRow(item: item, isPlaying: false)
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .nightGround()
        }
    }

    private func fetch() async {
        guard let client = SourceStore(database: .shared).jellyfinClient(for: route.source) else {
            load = .failed("Sunucu oturumu bulunamadı. Ayarlar › Kaynaklar'dan sunucuyu silip yeniden ekleyin.")
            return
        }
        do {
            if let parent = route.parent {
                load = .loaded(try await client.children(of: parent.id))
            } else {
                load = .loaded(try await client.libraries())
            }
        } catch {
            load = .failed(error.localizedDescription)
        }
    }
}

private struct MediaRow: View {
    let item: JellyfinClient.Item
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.textMutedOnSurface)
                .frame(width: Theme.Size.channelLogo)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .foregroundStyle(isPlaying ? Theme.accent : Theme.text)
                    .lineLimit(2)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.textMutedOnSurface)
                }
            }
        }
        .frame(minHeight: Theme.Size.tapMin)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch item.type {
        case "CollectionFolder", "UserView", "Folder": item.collectionType == "tvshows" ? "tv" : "film.stack"
        case "Series": "tv"
        case "Season": "square.stack"
        default: "play.rectangle"
        }
    }

    /// Runtime and how far in, e.g. "1 sa 52 dk · 38 dk izlendi".
    private var detail: String? {
        var parts: [String] = []
        if let ticks = item.runTimeTicks {
            parts.append(Duration.seconds(Double(ticks) / Double(JellyfinClient.ticksPerSecond))
                .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
        }
        if let resume = item.resumeSeconds {
            parts.append(Duration.seconds(resume).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)) + " izlendi")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
