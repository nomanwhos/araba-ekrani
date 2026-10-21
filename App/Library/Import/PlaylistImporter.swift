import Foundation
import GRDB

/// Writes parsed playlist entries for one source in a single transaction.
///
/// Upserts by `(source_id, stable_key)`, so importing the same playlist twice
/// changes nothing and channel ids (and anything keyed on them) survive a
/// refresh. Entries that disappeared from the playlist are deleted; their
/// favourites and positions are left for the orphan cleanup.
struct PlaylistImporter {
    struct Result: Equatable {
        var channels: Int
        var groups: Int
        var removed: Int
    }

    let database: AppDatabase

    func importEntries(_ entries: [PlaylistEntry], into sourceID: String) throws -> Result {
        try database.writer.write { db in
            try db.execute(sql: "CREATE TEMP TABLE IF NOT EXISTS seen_channels (id TEXT PRIMARY KEY)")
            try db.execute(sql: "CREATE TEMP TABLE IF NOT EXISTS seen_groups (id TEXT PRIMARY KEY)")
            try db.execute(sql: "DELETE FROM seen_channels")
            try db.execute(sql: "DELETE FROM seen_groups")

            let upsertGroup = try db.cachedStatement(sql: """
                INSERT INTO channel_groups (id, source_id, title, position) VALUES (?, ?, ?, ?)
                ON CONFLICT (source_id, title) DO UPDATE SET position = excluded.position
                RETURNING id
                """)
            let upsertChannel = try db.cachedStatement(sql: """
                INSERT INTO channels (id, source_id, group_id, stable_key, name, logo_url, tvg_id, position)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (source_id, stable_key) DO UPDATE SET
                  group_id = excluded.group_id, name = excluded.name, logo_url = excluded.logo_url,
                  tvg_id = excluded.tvg_id, position = excluded.position
                RETURNING id
                """)
            let clearStreams = try db.cachedStatement(sql: "DELETE FROM channel_streams WHERE channel_id = ?")
            let insertStream = try db.cachedStatement(sql: "INSERT INTO channel_streams (id, channel_id, url, position) VALUES (?, ?, ?, 0)")
            let markChannel = try db.cachedStatement(sql: "INSERT OR IGNORE INTO seen_channels (id) VALUES (?)")
            let markGroup = try db.cachedStatement(sql: "INSERT OR IGNORE INTO seen_groups (id) VALUES (?)")

            var keys = StableKeyMaker()
            var groupIDs: [String: String] = [:]
            var positionInGroup: [String: Int] = [:]

            for entry in entries {
                var groupID: String?
                if let title = entry.group {
                    if let known = groupIDs[title] {
                        groupID = known
                    } else {
                        let id = try String.fetchOne(upsertGroup, arguments: [UUID().uuidString, sourceID, title, groupIDs.count])!
                        try markGroup.execute(arguments: [id])
                        groupIDs[title] = id
                        groupID = id
                    }
                }
                let slot = groupID ?? ""
                let position = positionInGroup[slot, default: 0]
                positionInGroup[slot] = position + 1

                let channelID = try String.fetchOne(upsertChannel, arguments: [
                    UUID().uuidString, sourceID, groupID, keys.key(for: entry), entry.name,
                    entry.logoURL?.absoluteString, entry.tvgID, position,
                ])!
                try markChannel.execute(arguments: [channelID])
                try clearStreams.execute(arguments: [channelID])
                try insertStream.execute(arguments: [UUID().uuidString, channelID, entry.streamURL.absoluteString])
            }

            try db.execute(sql: "DELETE FROM channels WHERE source_id = ? AND id NOT IN (SELECT id FROM seen_channels)",
                           arguments: [sourceID])
            let removed = db.changesCount
            try db.execute(sql: "DELETE FROM channel_groups WHERE source_id = ? AND id NOT IN (SELECT id FROM seen_groups)",
                           arguments: [sourceID])
            try db.execute(sql: "UPDATE sources SET status = 'ok', last_error = NULL, last_refreshed_at = ?, updated_at = ? WHERE id = ?",
                           arguments: [Clock.now(), Clock.now(), sourceID])
            return Result(channels: entries.count, groups: groupIDs.count, removed: removed)
        }
    }
}
