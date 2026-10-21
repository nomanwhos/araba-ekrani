import Foundation

/// Turns a stored stream address into the URL the player opens.
/// Stored addresses never hold credentials; this adds them at play time.
struct StreamResolver {
    private static let xtreamPrefix = "xtream:live/"

    let database: AppDatabase

    func playableURL(for stored: URL, sourceID: String) -> URL? {
        let text = stored.absoluteString
        guard text.hasPrefix(Self.xtreamPrefix) else { return stored }
        let store = SourceStore(database: database)
        guard let source = try? store.source(id: sourceID), let client = store.xtreamClient(for: source) else { return nil }
        return client.liveURL(path: String(text.dropFirst(Self.xtreamPrefix.count)))
    }
}
