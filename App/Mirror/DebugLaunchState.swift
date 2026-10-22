#if DEBUG
import Foundation
import GRDB

/// Lets CI screenshots show each state without a car or a live broadcast:
/// `xcrun simctl launch <udid> <bundle> -TorpidoStage live -TorpidoTab settings`
enum DebugLaunchState {
    @MainActor
    static func apply() {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "TorpidoStage") {
        case "ready":
            MirrorState.shared.isCarConnected = true
        case "live":
            MirrorState.shared.isCarConnected = true
            MirrorState.shared.isStreaming = true
            MirrorState.shared.framesPerSecond = 30
        default:
            break
        }
    }

    /// `-TorpidoPlay 1`: starts the first seeded channel, for the player screenshot.
    static var autoplays: Bool {
        UserDefaults.standard.bool(forKey: "TorpidoPlay")
    }

    static var showsCatalog: Bool {
        UserDefaults.standard.bool(forKey: "TorpidoCatalog")
    }

    static var initialTab: RootView.TabID {
        UserDefaults.standard.string(forKey: "TorpidoTab").flatMap(RootView.TabID.init(rawValue:)) ?? .home
    }

    /// `-TorpidoSeed 1`: a small synthetic playlist so library screens have content.
    /// Streams are Apple's public HLS test streams; channel names are made up.
    /// `-TorpidoReset 1`: removes every source (and with it channels, favourites,
    /// positions, Keychain items) so each UI test starts from the same state.
    static func resetIfRequested() {
        guard UserDefaults.standard.bool(forKey: "TorpidoReset") else { return }
        let store = SourceStore(database: .shared)
        for source in (try? store.all()) ?? [] { try? store.remove(source) }
    }

    static func seedIfRequested() {
        guard UserDefaults.standard.bool(forKey: "TorpidoSeed"),
              (try? SourceStore(database: .shared).all().isEmpty) == true else { return }
        let bipbop = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        let groups = [("Haber", ["Haber 24", "Gündem TV", "Ekonomi Ekranı"]),
                      ("Spor", ["Spor Kanalı HD", "Maç Özeti", "Basketbol TV", "Motor Sporları"]),
                      ("Belgesel", ["Belgesel Dünyası", "Doğa ve Yaban", "Tarih Kanalı"]),
                      ("Çocuk", ["Çizgi Dünya", "Masal Saati"])]
        let entries = groups.flatMap { group, names in
            names.map { PlaylistEntry(name: $0, group: group, logoURL: nil, tvgID: nil, streamURL: URL(string: bipbop)!) }
        }
        do {
            let store = SourceStore(database: .shared)
            let source = try store.createM3U(url: URL(string: "https://example.invalid/ornek.m3u")!, name: "Örnek liste (sentetik)")
            _ = try PlaylistImporter(database: .shared).importEntries(entries, into: source.id)
            let channels = try AppDatabase.shared.reader.read { try Channel.order(Column("name")).fetchAll($0) }
            for channel in channels.prefix(2) { try FavoritesStore(database: .shared).toggle(channel) }
            try AppDatabase.shared.writer.write {
                try $0.execute(sql: "UPDATE channels SET health = 'ok', latency_ms = 180 WHERE name LIKE 'Haber%'")
                try $0.execute(sql: "UPDATE channels SET health = 'ok', latency_ms = 720 WHERE name = 'Spor Kanalı HD'")
            }
        } catch {
            assertionFailure("Seeding failed: \(error)")
        }
    }
}
#endif
