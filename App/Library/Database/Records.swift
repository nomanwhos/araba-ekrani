import Foundation
import GRDB

/// Shared snake_case <-> camelCase mapping for every table.
protocol SnakeCaseRecord: Codable, FetchableRecord, PersistableRecord {}

extension SnakeCaseRecord {
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }
}

struct Source: SnakeCaseRecord, Identifiable, Equatable, Hashable {
    static let databaseTableName = "sources"

    enum Kind: String, Codable, Hashable { case m3u, xtream, jellyfin, emby, plex }
    enum Status: String, Codable { case new, ok, failed }

    var id: String
    var kind: Kind
    var name: String
    var url: String
    var username: String?
    var keychainAccount: String?
    var status: Status
    var lastError: String?
    var lastRefreshedAt: Int64?
    var position: Int
    var createdAt: Int64
    var updatedAt: Int64
}

struct ChannelGroup: SnakeCaseRecord, Identifiable, Equatable, Hashable {
    static let databaseTableName = "channel_groups"

    var id: String
    var sourceId: String
    var title: String
    var position: Int
}

struct Channel: SnakeCaseRecord, Identifiable, Equatable, Hashable {
    static let databaseTableName = "channels"

    enum Health: String, Codable { case unknown, ok, down }

    var id: String
    var sourceId: String
    var groupId: String?
    var stableKey: String
    var name: String
    var logoUrl: String?
    var tvgId: String?
    var position: Int
    var health: Health
    var latencyMs: Int?
    var lastCheckedAt: Int64?
    /// `TurkishFold` of the name, for search.
    var searchName: String = ""

    /// How favourites and playback positions refer to this channel across refreshes.
    var itemKey: String { "\(sourceId):\(stableKey)" }

    var logoURL: URL? { logoUrl.flatMap(URL.init(string:)) }

    var displayHealth: ChannelHealth {
        switch health {
        case .unknown: .unknown
        case .down: .down
        case .ok: latencyMs.map { .ok(latencyMs: $0) } ?? .unknown
        }
    }
}

struct ChannelStream: SnakeCaseRecord, Identifiable, Equatable {
    static let databaseTableName = "channel_streams"

    var id: String
    var channelId: String
    var url: String
    var position: Int
}

struct Favorite: SnakeCaseRecord, Identifiable, Equatable {
    static let databaseTableName = "favorites"

    enum ItemKind: String, Codable { case channel, media, local }

    var id: String
    var itemKind: ItemKind
    var itemKey: String
    var sortOrder: Int
    var createdAt: Int64
}

struct PlaybackPosition: SnakeCaseRecord, Equatable {
    static let databaseTableName = "playback_positions"

    var itemKind: Favorite.ItemKind
    var itemKey: String
    var positionS: Double
    var durationS: Double?
    var updatedAt: Int64
}

struct LocalVideo: SnakeCaseRecord, Identifiable, Equatable, Hashable {
    static let databaseTableName = "local_videos"

    var id: String
    var fileName: String
    var displayName: String
    var folder: String
    var sortOrder: Int
    var byteSize: Int64
    var durationS: Double?
    var importedAt: Int64
}
