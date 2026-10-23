import Foundation
import GRDB

/// Turns what the owner typed into a page to open: a web address as is,
/// "youtube.com" with https added, anything else as a search.
enum BrowserAddress {
    private static let searchBase = "https://duckduckgo.com/?q="

    static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil {
            return url
        }
        let looksLikeHost = !trimmed.contains(" ") && trimmed.contains(".") && !trimmed.hasPrefix(".") && !trimmed.hasSuffix(".")
        if looksLikeHost, let url = URL(string: "https://" + trimmed), url.host != nil {
            return url
        }
        let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: searchBase + query)
    }
}

/// Starting points on the browser's first page. Text only: no third-party logos ship in the app.
struct QuickLink: Identifiable, Hashable {
    var name: String
    var url: URL
    var id: String { url.absoluteString }

    static let all: [QuickLink] = [
        QuickLink(name: "YouTube", url: URL(string: "https://m.youtube.com")!),
        QuickLink(name: "Netflix", url: URL(string: "https://www.netflix.com")!),
        QuickLink(name: "Prime Video", url: URL(string: "https://www.primevideo.com")!),
    ]
}

struct Bookmark: SnakeCaseRecord, Identifiable, Equatable, Hashable {
    static let databaseTableName = "bookmarks"

    var id: String
    var url: String
    var title: String
    var position: Int
    var createdAt: Int64
}

struct BookmarkStore {
    let database: AppDatabase

    /// Adds the page to the end of the bookmarks, or removes it if it is already there.
    func toggle(url: URL, title: String) throws {
        try database.writer.write { db in
            let existing = Bookmark.filter(Column("url") == url.absoluteString)
            if try existing.fetchCount(db) > 0 {
                try existing.deleteAll(db)
                return
            }
            let next = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(position) + 1, 0) FROM bookmarks") ?? 0
            let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
            try Bookmark(id: UUID().uuidString, url: url.absoluteString, title: name.isEmpty ? (url.host ?? url.absoluteString) : name,
                         position: next, createdAt: Clock.now()).insert(db)
        }
    }

    func remove(_ bookmark: Bookmark) throws {
        _ = try database.writer.write { try bookmark.delete($0) }
    }
}

extension LibraryQueries {
    static func bookmarks(_ db: Database) throws -> [Bookmark] {
        try Bookmark.order(Column("position")).fetchAll(db)
    }
}
