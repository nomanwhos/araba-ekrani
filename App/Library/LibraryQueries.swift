import Foundation
import GRDB

/// A group on Home: its title, how many live channels it has, and the first few.
struct HomeSection: Identifiable, Equatable {
    var group: ChannelGroup
    var total: Int
    var channels: [Channel]

    var id: String { group.id }
}

/// Read-only queries for the library screens. Each is a plain `(Database) -> value`
/// function: screens wrap it in `ValueObservation.tracking(...)` so they update
/// when an import or a favourite lands, and tests call it directly.
enum LibraryQueries {
    /// How many channels Home shows per group before "see all".
    static let homeRowLimit = 20

    static func sourceCount(_ db: Database) throws -> Int {
        try Source.fetchCount(db)
    }

    /// Every group in source then playlist order, with its first channels.
    /// Channels known to be down are hidden here (they stay in the group list).
    /// One query with window functions instead of one per group.
    static func homeSections(_ db: Database) throws -> [HomeSection] {
        let groups = try ChannelGroup.fetchAll(db, sql: """
            SELECT g.* FROM channel_groups g JOIN sources s ON s.id = g.source_id
            ORDER BY s.position, g.position
            """)
        let rows = try Row.fetchAll(db, sql: """
            SELECT * FROM (
              SELECT c.*,
                     ROW_NUMBER() OVER (PARTITION BY c.group_id ORDER BY c.position) AS rank_in_group,
                     COUNT(*) OVER (PARTITION BY c.group_id) AS group_total
              FROM channels c
              WHERE c.group_id IS NOT NULL AND c.health != 'down'
            ) WHERE rank_in_group <= ?
            """, arguments: [homeRowLimit])
        var channelsByGroup: [String: [Channel]] = [:]
        var totals: [String: Int] = [:]
        for row in rows {
            let channel = try Channel(row: row)
            guard let groupID = channel.groupId else { continue }
            channelsByGroup[groupID, default: []].append(channel)
            totals[groupID] = row["group_total"]
        }
        return groups.compactMap { group in
            guard let channels = channelsByGroup[group.id] else { return nil }
            return HomeSection(group: group, total: totals[group.id] ?? channels.count,
                               channels: channels.sorted { $0.position < $1.position })
        }
    }

    /// Channels with no group-title, shown under "Diğer" on Home.
    static func ungroupedChannels(_ db: Database) throws -> [Channel] {
        try Channel.filter(Column("group_id") == nil && Column("health") != "down").order(Column("position")).limit(homeRowLimit).fetchAll(db)
    }

    /// Every channel in a group, down ones included, in playlist order.
    static func channels(in groupID: String, _ db: Database) throws -> [Channel] {
        try Channel.filter(Column("group_id") == groupID).order(Column("position")).fetchAll(db)
    }

    /// Favourite channels in the owner's order.
    static func favoriteChannels(_ db: Database) throws -> [Channel] {
        try Channel.fetchAll(db, sql: """
            SELECT c.* FROM favorites f
            JOIN channels c ON f.item_kind = 'channel' AND f.item_key = c.source_id || ':' || c.stable_key
            ORDER BY f.sort_order
            """)
    }

    static func favoriteKeys(_ db: Database) throws -> Set<String> {
        Set(try String.fetchAll(db, sql: "SELECT item_key FROM favorites WHERE item_kind = 'channel'"))
    }

    /// Sources browsed live (Jellyfin), shown as rows at the top of Home.
    static func mediaServers(_ db: Database) throws -> [Source] {
        try Source.filter(Column("kind") == Source.Kind.jellyfin.rawValue).order(Column("position")).fetchAll(db)
    }

    static func sources(_ db: Database) throws -> [Source] {
        try Source.order(Column("position")).fetchAll(db)
    }

    static func firstStreamURL(for channel: Channel, _ db: Database) throws -> URL? {
        try String.fetchOne(db, sql: "SELECT url FROM channel_streams WHERE channel_id = ? ORDER BY position LIMIT 1",
                            arguments: [channel.id]).flatMap(URL.init(string:))
    }
}
