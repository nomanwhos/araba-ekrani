import Foundation

/// Turns a stored stream address into the URL the player opens.
/// Stored addresses never hold credentials; this adds them at play time.
struct StreamResolver {
    private static let xtreamPrefix = "xtream:live/"

    let database: AppDatabase

    func playableURL(for stored: URL, sourceID: String) -> URL? {
        let text = stored.absoluteString
        let store = SourceStore(database: database)
        if text.hasPrefix(CredentialStripper.marker) {
            guard let source = try? store.source(id: sourceID), let playlist = store.playlistURL(for: source),
                  let credentials = CredentialStripper.credentials(in: playlist) else { return nil }
            return CredentialStripper.fill(text, using: credentials)
        }
        guard text.hasPrefix(Self.xtreamPrefix) else { return stored }
        guard let source = try? store.source(id: sourceID), let client = store.xtreamClient(for: source) else { return nil }
        return client.liveURL(path: String(text.dropFirst(Self.xtreamPrefix.count)))
    }
}
