import SwiftUI

/// S09: the owner's playlists, with refresh and remove.
struct SourcesView: View {
    @State private var sources: [Source]?
    @State private var adding = false
    @State private var refreshing: Set<String> = []
    @State private var pendingRemoval: Source?
    @State private var message: String?

    var body: some View {
        Group {
            switch sources {
            case nil:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let sources? where sources.isEmpty:
                EmptyState(symbol: "list.bullet.rectangle", title: "Kaynak yok",
                           message: "M3U bağlantınızı ekleyin; kanallar Ana Sayfa'da görünür.",
                           actionTitle: "Kaynak ekle") { adding = true }
                    .frame(maxHeight: .infinity)
            case let sources?:
                List {
                    Section {
                        ForEach(sources) { source in
                            SourceRow(source: source, isRefreshing: refreshing.contains(source.id))
                                .swipeActions {
                                    Button("Sil", role: .destructive) { pendingRemoval = source }
                                    Button("Yenile") { refresh(source) }.tint(Theme.accent)
                                }
                        }
                    } footer: {
                        if let message {
                            Text(message).foregroundStyle(Theme.danger)
                        } else {
                            Text("Sola kaydırarak yenileyin ya da silin.")
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
                .nightGround()
            }
        }
        .background(Theme.bg)
        .navigationTitle("Kaynaklar")
        .miniPlayerInset()
        .toolbar {
            Button {
                adding = true
            } label: {
                Label("Kaynak ekle", systemImage: "plus")
            }
        }
        .sheet(isPresented: $adding) { AddSourceView() }
        .confirmationDialog("Kaynak silinsin mi?", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible,
                            presenting: pendingRemoval) { source in
            Button("\(source.name) listesini sil", role: .destructive) { remove(source) }
            Button("Vazgeç", role: .cancel) { pendingRemoval = nil }
        } message: { _ in
            Text("Listenin kanalları, favorileri ve kaldığınız yerler de silinir.")
        }
        .task {
            do {
                for try await value in AppDatabase.shared.observe(LibraryQueries.sources) { sources = value }
            } catch {
                sources = []
            }
        }
    }

    private func refresh(_ source: Source) {
        refreshing.insert(source.id)
        message = nil
        Task {
            do {
                try await SourceService(database: .shared).refresh(source)
            } catch {
                message = "\(source.name): \(error.localizedDescription)"
            }
            refreshing.remove(source.id)
        }
    }

    private func remove(_ source: Source) {
        pendingRemoval = nil
        do {
            try SourceStore(database: .shared).remove(source)
        } catch {
            message = String(localized: "Silinemedi: \(error.localizedDescription)")
        }
    }
}

private struct SourceRow: View {
    let source: Source
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .foregroundStyle(Theme.text)
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(source.status == .failed ? Theme.danger : Theme.textMutedOnSurface)
                    .lineLimit(2)
            }
            Spacer(minLength: Theme.Space.s8)
            if isRefreshing { ProgressView() }
        }
        .frame(minHeight: Theme.Size.tapMin)
        .accessibilityElement(children: .combine)
    }

    private var status: String {
        if source.status == .failed, let error = source.lastError { return error }
        guard let refreshed = source.lastRefreshedAt else { return String(localized: "Henüz indirilmedi") }
        let date = Date(timeIntervalSince1970: TimeInterval(refreshed))
        return String(localized: "Güncellendi: ") + date.formatted(.relative(presentation: .named))
    }
}
