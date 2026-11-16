import GRDB
import XCTest
@testable import Torpido

final class RecentQueriesTests: XCTestCase {
    func testRecentMixesChannelsAndVideosNewestFirst() async throws {
        let database = try AppDatabase.empty()
        let source = try SourceStore(database: database).createM3U(url: URL(string: "http://p.example/l.m3u")!, name: "T")
        _ = try PlaylistImporter(database: database).importEntries(["A", "B", "C"].map {
            PlaylistEntry(name: $0, group: "G", logoURL: nil, tvgID: nil, streamURL: URL(string: "http://s.example/\($0)")!)
        }, into: source.id)
        let channels = try await database.reader.read { try Channel.order(Column("position")).fetchAll($0) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("Yol.mp4")
        try Data(repeating: 1, count: 1024).write(to: file)
        let video = try await LocalVideoStore(database: database, folder: folder).importVideo(from: file)
        try await database.writer.write { db in
            try PlaybackPosition(itemKind: .channel, itemKey: channels[0].itemKey, positionS: 5, durationS: nil, updatedAt: 100).upsert(db)
            try PlaybackPosition(itemKind: .local, itemKey: video.id, positionS: 5, durationS: 60, updatedAt: 200).upsert(db)
            try PlaybackPosition(itemKind: .channel, itemKey: channels[2].itemKey, positionS: 5, durationS: nil, updatedAt: 300).upsert(db)
        }

        let recent = try await database.reader.read { try LibraryQueries.recentItems(limit: 10, $0) }
        let limited = try await database.reader.read { try LibraryQueries.recentItems(limit: 2, $0) }

        XCTAssertEqual(recent, [.channel(channels[2]), .video(video), .channel(channels[0])])
        XCTAssertEqual(limited, [.channel(channels[2]), .video(video)])
    }
}
