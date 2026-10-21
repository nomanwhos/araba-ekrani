import SwiftUI

/// S01: every group of every source, as rows of channel tiles.
struct HomeView: View {
    private enum Load: Equatable {
        case loading
        case loaded(sources: Int, sections: [HomeSection], ungrouped: [Channel])
        case failed(String)
    }

    @State private var load = Load.loading
    @State private var favorites: Set<String> = []
    @State private var addingSource = false
    private let player = PlayerController.shared

    var body: some View {
        NavigationStack {
            content
                .background(Theme.bg)
                .navigationTitle("Ana Sayfa")
                .toolbar {
                    Button {
                        addingSource = true
                    } label: {
                        Label("Kaynak ekle", systemImage: "plus")
                    }
                }
                .navigationDestination(for: ChannelGroup.self) { GroupView(group: $0) }
                .sheet(isPresented: $addingSource) { AddSourceView() }
                .miniPlayerInset()
        }
        .task { await observeLibrary() }
        .task { await observeFavorites() }
    }

    @ViewBuilder
    private var content: some View {
        switch load {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            EmptyState(symbol: "exclamationmark.triangle", title: "Kanallar okunamadı", message: message)
                .frame(maxHeight: .infinity)
        case .loaded(0, _, _):
            EmptyState(symbol: "tv", title: "Henüz kanal yok",
                       message: "Bir M3U bağlantısı ekleyin, kanallar burada gruplarıyla listelenir.",
                       actionTitle: "Kaynak ekle") { addingSource = true }
                .frame(maxHeight: .infinity)
        case .loaded(_, let sections, let ungrouped) where sections.isEmpty && ungrouped.isEmpty:
            EmptyState(symbol: "antenna.radiowaves.left.and.right.slash", title: "Açık kanal yok",
                       message: "Eklediğiniz listelerde şu an çalışan kanal bulunamadı. Ayarlar › Kaynaklar'dan listeyi yenileyin.")
                .frame(maxHeight: .infinity)
        case .loaded(_, let sections, let ungrouped):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.s24) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: Theme.Space.s8) {
                            NavigationLink(value: section.group) {
                                GroupHeaderLabel(title: section.group.title, count: section.total)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, Theme.Space.s16)
                            tileRow(section.channels)
                        }
                    }
                    if !ungrouped.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Space.s8) {
                            Text("Diğer")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Theme.text)
                                .padding(.horizontal, Theme.Space.s16)
                            tileRow(ungrouped)
                        }
                    }
                }
                .padding(.vertical, Theme.Space.s16)
            }
        }
    }

    private func tileRow(_ channels: [Channel]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Theme.Space.s12) {
                ForEach(channels) { channel in
                    Button {
                        player.play(channel)
                    } label: {
                        ChannelTile(channel: channel, isFavorite: favorites.contains(channel.itemKey),
                                    isPlaying: player.nowPlaying?.id == channel.id)
                    }
                    .buttonStyle(.plain)
                    .favoriteContextMenu(for: channel, isFavorite: favorites.contains(channel.itemKey))
                }
            }
            .padding(.horizontal, Theme.Space.s16)
        }
    }

    private func observeLibrary() async {
        do {
            for try await value in AppDatabase.shared.observe({ db in
                (try LibraryQueries.sourceCount(db), try LibraryQueries.homeSections(db), try LibraryQueries.ungroupedChannels(db))
            }) {
                load = .loaded(sources: value.0, sections: value.1, ungrouped: value.2)
            }
        } catch {
            load = .failed(error.localizedDescription)
        }
    }

    private func observeFavorites() async {
        do {
            for try await keys in AppDatabase.shared.observe(LibraryQueries.favoriteKeys) {
                favorites = keys
            }
        } catch {
            favorites = []
        }
    }
}

/// GroupHeader's look without its own button, for use inside a NavigationLink.
private struct GroupHeaderLabel: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: Theme.Space.s6) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text("\(count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textMuted)
            Spacer(minLength: Theme.Space.s8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(minHeight: Theme.Size.tapMin)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Gruptaki tüm kanalları gösterir")
    }
}
