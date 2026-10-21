import GRDB
import XCTest
@testable import Torpido

final class StoresTests: XCTestCase {
    private var database: AppDatabase!
    private var channel: Channel!

    override func setUpWithError() throws {
        database = try AppDatabase.empty()
        let source = try SourceStore(database: database).createM3U(url: URL(string: "http://p.example/l.m3u")!, name: "T")
        _ = try PlaylistImporter(database: database).importEntries([
            PlaylistEntry(name: "Film", group: "Sinema", logoURL: nil, tvgID: nil, streamURL: URL(string: "http://s.example/film.mp4")!),
        ], into: source.id)
        channel = try database.reader.read { try Channel.fetchOne($0) }
    }

    func testToggleAddsThenRemovesFavourite() throws {
        let favorites = FavoritesStore(database: database)

        try favorites.toggle(channel)
        XCTAssertTrue(try favorites.isFavorite(channel))

        try favorites.toggle(channel)
        XCTAssertFalse(try favorites.isFavorite(channel))
    }

    func testResumesOnlyMeaningfulOnDemandPositions() throws {
        let positions = PlaybackPositionStore(database: database)

        try positions.save(channel: channel, position: 600, duration: 5400)
        XCTAssertEqual(try positions.resumePosition(for: channel), 600)

        try positions.save(channel: channel, position: 10, duration: 5400)
        XCTAssertNil(try positions.resumePosition(for: channel), "too close to the start")

        try positions.save(channel: channel, position: 5395, duration: 5400)
        XCTAssertNil(try positions.resumePosition(for: channel), "already finished")

        try positions.save(channel: channel, position: 600, duration: nil)
        XCTAssertNil(try positions.resumePosition(for: channel), "live streams start live")
    }

    func testRemovingSourceAlsoRemovesItsFavouritesAndPositions() throws {
        try FavoritesStore(database: database).toggle(channel)
        try PlaybackPositionStore(database: database).save(channel: channel, position: 600, duration: 5400)
        let store = SourceStore(database: database)

        try store.remove(try XCTUnwrap(store.all().first))

        let leftovers = try database.reader.read {
            try Int.fetchOne($0, sql: "SELECT (SELECT COUNT(*) FROM favorites) + (SELECT COUNT(*) FROM playback_positions)")
        }
        XCTAssertEqual(leftovers, 0)
    }
}
