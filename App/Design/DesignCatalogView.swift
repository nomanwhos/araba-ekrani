#if DEBUG
import SwiftUI

/// Every v2 primitive in its states, in isolation, for the CI screenshot
/// (`-TorpidoCatalog 1`). Not reachable in release builds.
struct DesignCatalogView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Kanal satırı") {
                    ChannelRow(name: "TRT 1", logoURL: nil, group: "Ulusal", health: .ok(latencyMs: 142))
                    ChannelRow(name: "Spor Kanalı HD", logoURL: nil, group: "Spor", health: .ok(latencyMs: 640), isFavorite: true)
                    ChannelRow(name: "Belgesel Dünyası", logoURL: nil, health: .ok(latencyMs: 1480))
                    ChannelRow(name: "Çocuk Kanalı", logoURL: nil, group: "Çocuk", health: .down)
                    ChannelRow(name: "Haber 24", logoURL: nil, group: "Haber", isPlaying: true)
                }
                .listRowBackground(Theme.surface)

                Section("Grup başlığı") {
                    GroupHeader(title: "Spor", count: 48) {}
                    GroupHeader(title: "Uzun bir grup adı ekrana sığmadığında kesilir", count: 1204) {}
                }
                .listRowBackground(Theme.bg)

                Section("Kaynak türleri") {
                    ForEach(SourceKind.allCases) { SourceKindLabel(kind: $0) }
                }
                .listRowBackground(Theme.surface)

                Section("Boş durum") {
                    EmptyState(symbol: "tv", title: "Henüz kanal yok",
                               message: "Bir M3U bağlantısı ekleyin, kanallar burada gruplarıyla listelenir.",
                               actionTitle: "Kaynak ekle") {}
                    EmptyState(symbol: "star", title: "Favori yok",
                               message: "Bir kanalın yıldızına dokunduğunuzda buraya gelir.")
                }
                .listRowBackground(Theme.bg)

                Section("Mini oynatıcı") {
                    MiniPlayerBar(title: "Haber 24", subtitle: "Haber", isPlaying: true, togglePlayback: {}, expand: {})
                    MiniPlayerBar(title: "Belgesel Dünyası", subtitle: nil, isPlaying: false, togglePlayback: {}, expand: {})
                }
                .listRowBackground(Theme.bg)
                .listRowInsets(EdgeInsets())
            }
            .nightGround()
            .navigationTitle("Bileşenler")
        }
        .preferredColorScheme(.dark)
    }
}
#endif
