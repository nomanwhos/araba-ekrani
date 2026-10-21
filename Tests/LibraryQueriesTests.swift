import GRDB
import XCTest
@testable import Torpido

final class LibraryQueriesTests: XCTestCase {
    func testHomeSectionsLimitRowsHideDownChannelsAndKeepOrder() throws {
        let database = try AppDatabase.empty()
        let source = try SourceStore(database: database).createM3U(url: URL(string: "http://p.example/l.m3u")!, name: "T")
        let entries = (0..<30).map {
            PlaylistEntry(name: "Kanal \($0)", group: $0 < 25 ? "Büyük" : "Küçük", logoURL: nil, tvgID: nil,
                          streamURL: URL(string: "http://s.example/\($0)")!)
        }
        _ = try PlaylistImporter(database: database).importEntries(entries, into: source.id)
        try database.writer.write { try $0.execute(sql: "UPDATE channels SET health = 'down' WHERE name = 'Kanal 0'") }

        let sections = try database.reader.read { try LibraryQueries.homeSections($0) }

        XCTAssertEqual(sections.map(\.group.title), ["Büyük", "Küçük"])
        XCTAssertEqual(sections[0].channels.count, LibraryQueries.homeRowLimit)
        XCTAssertEqual(sections[0].total, 24, "the down channel is not counted on Home")
        XCTAssertEqual(sections[0].channels.first?.name, "Kanal 1")
        XCTAssertEqual(sections[1].channels.map(\.name), (25..<30).map { "Kanal \($0)" })
    }

    func testFavouriteChannelsFollowSortOrder() throws {
        let database = try AppDatabase.empty()
        let source = try SourceStore(database: database).createM3U(url: URL(string: "http://p.example/l.m3u")!, name: "T")
        _ = try PlaylistImporter(database: database).importEntries(["A", "B", "C"].map {
            PlaylistEntry(name: $0, group: "G", logoURL: nil, tvgID: nil, streamURL: URL(string: "http://s.example/\($0)")!)
        }, into: source.id)
        let channels = try database.reader.read { try Channel.order(Column("position")).fetchAll($0) }
        let favorites = FavoritesStore(database: database)
        try favorites.toggle(channels[2])
        try favorites.toggle(channels[0])

        let names = try database.reader.read { try LibraryQueries.favoriteChannels($0) }.map(\.name)

        XCTAssertEqual(names, ["C", "A"])
    }
}
