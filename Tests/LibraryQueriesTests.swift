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

    private func searchDatabase() throws -> AppDatabase {
        let database = try AppDatabase.empty()
        let source = try SourceStore(database: database).createM3U(url: URL(string: "http://p.example/l.m3u")!, name: "T")
        let names = ["Tarih Kanalı", "Çizgi Dünya", "İSTANBUL TV", "Spor Kanalı HD", "100% Müzik", "Haber_24"]
        _ = try PlaylistImporter(database: database).importEntries(names.map {
            PlaylistEntry(name: $0, group: "G", logoURL: nil, tvgID: nil, streamURL: URL(string: "http://s.example/x")!)
        }, into: source.id)
        return database
    }

    private func search(_ text: String, in database: AppDatabase) throws -> [String] {
        try database.reader.read { try LibraryQueries.search(text, $0) }.map(\.name)
    }

    func testSearchIgnoresTurkishCaseAndAccents() throws {
        let database = try searchDatabase()

        XCTAssertEqual(try search("kanali", in: database), ["Tarih Kanalı", "Spor Kanalı HD"])
        XCTAssertEqual(try search("cizgi", in: database), ["Çizgi Dünya"])
        XCTAssertEqual(try search("istanbul", in: database), ["İSTANBUL TV"])
        XCTAssertEqual(try search("DÜNYA", in: database), ["Çizgi Dünya"])
    }

    func testSearchNeedsEveryWord() throws {
        let database = try searchDatabase()

        XCTAssertEqual(try search("spor hd", in: database), ["Spor Kanalı HD"])
        XCTAssertEqual(try search("spor tarih", in: database), [])
    }

    func testSearchTreatsWildcardsAsText() throws {
        let database = try searchDatabase()

        XCTAssertEqual(try search("100%", in: database), ["100% Müzik"])
        XCTAssertEqual(try search("%", in: database), ["100% Müzik"])
        XCTAssertEqual(try search("_", in: database), ["Haber_24"])
        XCTAssertEqual(try search("   ", in: database), [])
    }

    func testSearchHistoryKeepsNewestFirstWithoutDuplicates() throws {
        let database = try AppDatabase.empty()
        let history = SearchHistoryStore(database: database)

        try history.record("spor")
        try history.record("haber")
        try history.record("spor")

        XCTAssertEqual(try database.reader.read { try LibraryQueries.recentSearches($0) }.first, "spor")
        XCTAssertEqual(try database.reader.read { try LibraryQueries.recentSearches($0) }.count, 2)
    }
}
