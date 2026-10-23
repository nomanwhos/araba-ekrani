import Foundation
import GRDB

/// Sources the owner added: create, list, remove.
struct SourceStore {
    let database: AppDatabase

    /// Playlist links usually carry the IPTV username and password in the query
    /// or user-info. Those links go to the Keychain; the database keeps only a
    /// credential-free form for display.
    func createM3U(url: URL, name: String) throws -> Source {
        let shown = Self.displayURL(url)
        return try create(kind: .m3u, name: name, url: shown, username: nil,
                          secret: shown == url.absoluteString ? nil : url.absoluteString)
    }

    /// Xtream: server address and username in the database, password in the Keychain.
    func createXtream(server: URL, username: String, password: String, name: String) throws -> Source {
        try create(kind: .xtream, name: name, url: server.absoluteString, username: username,
                   secret: SourceSecret(password: password).encoded())
    }

    /// Jellyfin: server and username in the database, access token and user id in the Keychain.
    func createJellyfin(server: URL, username: String, session: JellyfinClient.Session, name: String) throws -> Source {
        let source = try create(kind: .jellyfin, name: name, url: server.absoluteString, username: username,
                                secret: SourceSecret(token: session.token, userID: session.userID).encoded())
        try database.writer.write { db in
            try db.execute(sql: "UPDATE sources SET status = 'ok', last_refreshed_at = ? WHERE id = ?",
                           arguments: [Clock.now(), source.id])
        }
        return source
    }

    private func create(kind: Source.Kind, name: String, url: String, username: String?, secret: String?) throws -> Source {
        let id = UUID().uuidString
        let account = secret == nil ? nil : id
        if let account, let secret { try Keychain.set(secret, account: account) }
        do {
            return try database.writer.write { db in
                let position = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(position) + 1, 0) FROM sources") ?? 0
                let source = Source(
                    id: id, kind: kind, name: name, url: url,
                    username: username, keychainAccount: account, status: .new, lastError: nil, lastRefreshedAt: nil,
                    position: position, createdAt: Clock.now(), updatedAt: Clock.now()
                )
                try source.insert(db)
                return source
            }
        } catch {
            if let account { Keychain.delete(account: account) }
            throw error
        }
    }

    func xtreamClient(for source: Source) -> XtreamClient? {
        guard source.kind == .xtream, let server = URL(string: source.url), let username = source.username,
              let password = secret(for: source)?.password else { return nil }
        return XtreamClient(server: server, username: username, password: password)
    }

    func jellyfinClient(for source: Source) -> JellyfinClient? {
        guard source.kind == .jellyfin, let server = URL(string: source.url),
              let token = secret(for: source)?.token, let userID = secret(for: source)?.userID else { return nil }
        return JellyfinClient(server: server, session: .init(token: token, userID: userID))
    }

    private func secret(for source: Source) -> SourceSecret? {
        source.keychainAccount.flatMap { Keychain.get(account: $0) }.flatMap(SourceSecret.decode)
    }

    /// The real download address of an M3U source, credentials included.
    func playlistURL(for source: Source) -> URL? {
        let text = source.keychainAccount.flatMap { Keychain.get(account: $0) } ?? source.url
        return URL(string: text)
    }

    static func displayURL(_ url: URL) -> String {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        parts.user = nil
        parts.password = nil
        parts.query = nil
        parts.fragment = nil
        return parts.url?.absoluteString ?? url.absoluteString
    }

    func markRefreshed(_ sourceID: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE sources SET status = 'ok', last_error = NULL, last_refreshed_at = ?, updated_at = ? WHERE id = ?",
                           arguments: [Clock.now(), Clock.now(), sourceID])
        }
    }

    func markFailed(_ sourceID: String, message: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE sources SET status = 'failed', last_error = ?, updated_at = ? WHERE id = ?",
                           arguments: [message, Clock.now(), sourceID])
        }
    }

    /// Removes the source, its groups, channels and streams (cascade), then
    /// favourites and positions that pointed at its channels.
    func remove(_ source: Source) throws {
        try database.writer.write { db in
            _ = try source.delete(db)
            try OrphanCleanup.run(db)
        }
        if let account = source.keychainAccount { Keychain.delete(account: account) }
    }

    func source(id: String) throws -> Source? {
        try database.reader.read { try Source.fetchOne($0, key: id) }
    }

    func all() throws -> [Source] {
        try database.reader.read { try Source.order(Column("position")).fetchAll($0) }
    }
}

/// What a source keeps in the Keychain, stored as JSON. (M3U sources store the full URL instead.)
struct SourceSecret: Codable, Equatable {
    var password: String?
    var token: String?
    var userID: String?

    func encoded() -> String {
        String(decoding: (try? JSONEncoder().encode(self)) ?? Data(), as: UTF8.self)
    }

    static func decode(_ text: String) -> SourceSecret? {
        try? JSONDecoder().decode(SourceSecret.self, from: Data(text.utf8))
    }
}

/// Deletes favourites and playback positions whose channel no longer exists.
enum OrphanCleanup {
    static func run(_ db: Database) throws {
        for table in ["favorites", "playback_positions"] {
            try db.execute(sql: """
                DELETE FROM \(table) WHERE item_kind = 'channel'
                AND item_key NOT IN (SELECT source_id || ':' || stable_key FROM channels)
                """)
            try db.execute(sql: "DELETE FROM \(table) WHERE item_kind = 'local' AND item_key NOT IN (SELECT id FROM local_videos)")
        }
    }
}

struct FavoritesStore {
    let database: AppDatabase

    func isFavorite(_ channel: Channel) throws -> Bool {
        try database.reader.read { db in
            try Favorite.filter(Column("item_kind") == "channel" && Column("item_key") == channel.itemKey).fetchCount(db) > 0
        }
    }

    /// Adds the channel to the end of the favourites, or removes it.
    func toggle(_ channel: Channel) throws {
        try database.writer.write { db in
            let existing = Favorite.filter(Column("item_kind") == "channel" && Column("item_key") == channel.itemKey)
            if try existing.fetchCount(db) > 0 {
                try existing.deleteAll(db)
                return
            }
            let next = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sort_order) + 1, 0) FROM favorites") ?? 0
            try Favorite(id: UUID().uuidString, itemKind: .channel, itemKey: channel.itemKey,
                         sortOrder: next, createdAt: Clock.now()).insert(db)
        }
    }
}

struct SearchHistoryStore {
    private static let keep = 50

    let database: AppDatabase

    /// Records a submitted search; repeating one moves it to the top.
    func record(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO search_queries (id, text, searched_at)
                VALUES (?, ?, MAX(?, COALESCE((SELECT MAX(searched_at) FROM search_queries), 0) + 1))
                ON CONFLICT (text) DO UPDATE SET searched_at = excluded.searched_at
                """, arguments: [UUID().uuidString, trimmed, Clock.now()])
            // searched_at always moves forward, so two searches in the same second keep their order.
            try db.execute(sql: """
                DELETE FROM search_queries WHERE id NOT IN
                  (SELECT id FROM search_queries ORDER BY searched_at DESC LIMIT ?)
                """, arguments: [Self.keep])
        }
    }

    func clear() throws {
        try database.writer.write { try $0.execute(sql: "DELETE FROM search_queries") }
    }
}

struct PlaybackPositionStore {
    /// Shorter than this and resuming is more annoying than useful.
    private static let minimumResumeSeconds = 30.0
    /// Within this of the end counts as finished.
    private static let finishedMarginSeconds = 20.0

    let database: AppDatabase

    func save(channel: Channel, position: Double, duration: Double?) throws {
        try save(kind: .channel, key: channel.itemKey, position: position, duration: duration)
    }

    func resumePosition(for channel: Channel) throws -> Double? {
        try resumePosition(kind: .channel, key: channel.itemKey)
    }

    func save(kind: Favorite.ItemKind, key: String, position: Double, duration: Double?) throws {
        try database.writer.write { db in
            try PlaybackPosition(itemKind: kind, itemKey: key, positionS: max(0, position),
                                 durationS: duration, updatedAt: Clock.now()).upsert(db)
        }
    }

    /// Where to start: the saved position for on-demand video, nil for live
    /// streams, near-zero positions and finished videos.
    func resumePosition(kind: Favorite.ItemKind, key: String) throws -> Double? {
        try database.reader.read { db in
            guard let saved = try PlaybackPosition
                .filter(Column("item_kind") == kind.rawValue && Column("item_key") == key)
                .fetchOne(db),
                let duration = saved.durationS
            else { return nil }
            let unfinished = saved.positionS < duration - Self.finishedMarginSeconds
            return saved.positionS >= Self.minimumResumeSeconds && unfinished ? saved.positionS : nil
        }
    }
}
