import Foundation
import GRDB

/// Sources the owner added: create, list, remove.
struct SourceStore {
    let database: AppDatabase

    /// Playlist links usually carry the IPTV username and password in the query
    /// or user-info. Those links go to the Keychain; the database keeps only a
    /// credential-free form for display.
    func createM3U(url: URL, name: String) throws -> Source {
        let id = UUID().uuidString
        let shown = Self.displayURL(url)
        let account = shown == url.absoluteString ? nil : id
        if let account { try Keychain.set(url.absoluteString, account: account) }
        do {
            return try database.writer.write { db in
                let position = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(position) + 1, 0) FROM sources") ?? 0
                let source = Source(
                    id: id, kind: .m3u, name: name, url: shown,
                    username: nil, keychainAccount: account, status: .new, lastError: nil, lastRefreshedAt: nil,
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

    /// The real download address, credentials included.
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

    func all() throws -> [Source] {
        try database.reader.read { try Source.order(Column("position")).fetchAll($0) }
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

struct PlaybackPositionStore {
    /// Shorter than this and resuming is more annoying than useful.
    private static let minimumResumeSeconds = 30.0
    /// Within this of the end counts as finished.
    private static let finishedMarginSeconds = 20.0

    let database: AppDatabase

    func save(channel: Channel, position: Double, duration: Double?) throws {
        try database.writer.write { db in
            try PlaybackPosition(itemKind: .channel, itemKey: channel.itemKey, positionS: max(0, position),
                                 durationS: duration, updatedAt: Clock.now()).upsert(db)
        }
    }

    /// Where to start: the saved position for on-demand video, nil for live
    /// streams, near-zero positions and finished videos.
    func resumePosition(for channel: Channel) throws -> Double? {
        try database.reader.read { db in
            guard let saved = try PlaybackPosition
                .filter(Column("item_kind") == "channel" && Column("item_key") == channel.itemKey)
                .fetchOne(db),
                let duration = saved.durationS
            else { return nil }
            let unfinished = saved.positionS < duration - Self.finishedMarginSeconds
            return saved.positionS >= Self.minimumResumeSeconds && unfinished ? saved.positionS : nil
        }
    }
}
