import GRDB

/// Something the owner played recently: a playlist channel or an imported video.
enum RecentItem: Equatable {
    case channel(Channel)
    case video(LocalVideo)
}

extension LibraryQueries {
    /// Channels and imported videos by when they last played, newest first.
    /// Built from saved playback positions, so it fills as the owner watches.
    static func recentItems(limit: Int, _ db: Database) throws -> [RecentItem] {
        let channelRows = try Row.fetchAll(db, sql: """
            SELECT c.*, p.updated_at AS recent_at FROM playback_positions p
            JOIN channels c ON p.item_kind = 'channel' AND p.item_key = c.source_id || ':' || c.stable_key
            ORDER BY p.updated_at DESC LIMIT ?
            """, arguments: [limit])
        let videoRows = try Row.fetchAll(db, sql: """
            SELECT v.*, p.updated_at AS recent_at FROM playback_positions p
            JOIN local_videos v ON p.item_kind = 'local' AND p.item_key = v.id
            ORDER BY p.updated_at DESC LIMIT ?
            """, arguments: [limit])
        let channels = try channelRows.map { (at: $0["recent_at"] as Int64, item: RecentItem.channel(try Channel(row: $0))) }
        let videos = try videoRows.map { (at: $0["recent_at"] as Int64, item: RecentItem.video(try LocalVideo(row: $0))) }
        return (channels + videos).sorted { $0.at > $1.at }.prefix(limit).map(\.item)
    }
}
