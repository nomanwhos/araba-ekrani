import GRDB
import XCTest
@testable import Torpido

final class PlaylistImporterTests: XCTestCase {
    private var database: AppDatabase!
    private var sources: SourceStore!

    override func setUpWithError() throws {
        database = try AppDatabase.empty()
        sources = SourceStore(database: database)
    }

    private func entry(_ name: String, _ group: String?, _ path: String) -> PlaylistEntry {
        PlaylistEntry(name: name, group: group, logoURL: nil, tvgID: nil, streamURL: URL(string: "http://s.example/\(path)")!)
    }

    private func channelNames() throws -> [String] {
        try database.reader.read { try String.fetchAll($0, sql: "SELECT name FROM channels ORDER BY name") }
    }

    func testImportCreatesGroupsChannelsAndStreams() throws {
        let source = try sources.createM3U(url: URL(string: "http://p.example/list.m3u")!, name: "Test")

        let result = try PlaylistImporter(database: database).importEntries([
            entry("Bir", "A", "1"), entry("İki", "A", "2"), entry("Üç", nil, "3"),
        ], into: source.id)

        XCTAssertEqual(result, .init(channels: 3, groups: 1, removed: 0))
        XCTAssertEqual(try channelNames(), ["Bir", "Üç", "İki"])
        let streams = try database.reader.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM channel_streams") }
        XCTAssertEqual(streams, 3)
        let status = try database.reader.read { try String.fetchOne($0, sql: "SELECT status FROM sources") }
        XCTAssertEqual(status, "ok")
    }

    func testReimportKeepsChannelIDsAndFavourites() throws {
        let source = try sources.createM3U(url: URL(string: "http://p.example/list.m3u")!, name: "Test")
        let importer = PlaylistImporter(database: database)
        _ = try importer.importEntries([entry("Bir", "A", "1"), entry("İki", "A", "2")], into: source.id)
        let before = try database.reader.read { try Channel.fetchAll($0).sorted { $0.name < $1.name } }
        try FavoritesStore(database: database).toggle(before[0])

        _ = try importer.importEntries([entry("BİR", "a", "1-new"), entry("İki", "A", "2")], into: source.id)

        let after = try database.reader.read { try Channel.fetchAll($0).sorted { $0.name < $1.name } }
        XCTAssertEqual(Set(after.map(\.id)), Set(before.map(\.id)))
        XCTAssertTrue(try FavoritesStore(database: database).isFavorite(before[0]))
        let url = try database.reader.read {
            try String.fetchOne($0, sql: "SELECT url FROM channel_streams WHERE channel_id = ?", arguments: [before[0].id])
        }
        XCTAssertEqual(url, "http://s.example/1-new")
    }

    func testReimportRemovesEntriesThatDisappeared() throws {
        let source = try sources.createM3U(url: URL(string: "http://p.example/list.m3u")!, name: "Test")
        let importer = PlaylistImporter(database: database)
        _ = try importer.importEntries([entry("Bir", "A", "1"), entry("İki", "B", "2")], into: source.id)

        let result = try importer.importEntries([entry("Bir", "A", "1")], into: source.id)

        XCTAssertEqual(result.removed, 1)
        XCTAssertEqual(try channelNames(), ["Bir"])
        let groups = try database.reader.read { try String.fetchAll($0, sql: "SELECT title FROM channel_groups") }
        XCTAssertEqual(groups, ["A"])
    }

    func testDeletingASourceCascadesToItsChannels() throws {
        let source = try sources.createM3U(url: URL(string: "http://p.example/list.m3u")!, name: "Test")
        _ = try PlaylistImporter(database: database).importEntries([entry("Bir", "A", "1")], into: source.id)

        try sources.remove(source)

        XCTAssertEqual(try channelNames(), [])
    }

    func testTwentyThousandEntriesImportInOneTransaction() throws {
        let source = try sources.createM3U(url: URL(string: "http://p.example/big.m3u")!, name: "Büyük")
        let entries = (0..<20_000).map { entry("Kanal \($0)", "Grup \($0 % 200)", "\($0)") }
        let started = Date()

        let result = try PlaylistImporter(database: database).importEntries(entries, into: source.id)

        XCTAssertEqual(result.channels, 20_000)
        XCTAssertEqual(result.groups, 200)
        XCTAssertLessThan(Date().timeIntervalSince(started), 20, "import is far too slow")
    }
}
