import GRDB
import XCTest
@testable import Torpido

final class LocalVideoStoreTests: XCTestCase {
    private var folder: URL!
    private var database: AppDatabase!
    private var store: LocalVideoStore!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        database = try AppDatabase.empty()
        store = LocalVideoStore(database: database, folder: folder)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func sampleFile(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try Data(repeating: 7, count: 2048).write(to: url)
        return url
    }

    func testImportCopiesTheFileAndNamesItAfterTheSource() async throws {
        let source = try sampleFile("Kamp Gecesi.mp4")

        let video = try await store.importVideo(from: source)

        XCTAssertEqual(video.displayName, "Kamp Gecesi")
        XCTAssertEqual(video.byteSize, 2048)
        XCTAssertTrue(video.fileName.hasSuffix(".mp4"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL(for: video).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "the original stays where it was")
    }

    func testRenameKeepsTheFile() async throws {
        let video = try await store.importVideo(from: try sampleFile("a.mov"))

        try store.rename(video, to: "  Çocuk filmi  ")

        let renamed = try await database.reader.read { try LocalVideo.fetchOne($0, key: video.id) }
        XCTAssertEqual(renamed?.displayName, "Çocuk filmi")
        XCTAssertEqual(renamed?.fileName, video.fileName)
    }

    func testDeleteRemovesFileRowAndResumePosition() async throws {
        let video = try await store.importVideo(from: try sampleFile("b.mov"))
        try PlaybackPositionStore(database: database).save(kind: .local, key: video.id, position: 120, duration: 600)

        try store.delete(video)

        let rows = try await database.reader.read {
            try Int.fetchOne($0, sql: "SELECT (SELECT COUNT(*) FROM local_videos) + (SELECT COUNT(*) FROM playback_positions)")
        }
        XCTAssertEqual(rows, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL(for: video).path))
    }

    func testOrderFollowsImportOrder() async throws {
        _ = try await store.importVideo(from: try sampleFile("ilk.mov"))
        _ = try await store.importVideo(from: try sampleFile("ikinci.mov"))

        let names = try await database.reader.read { try LibraryQueries.localVideos($0) }.map(\.displayName)

        XCTAssertEqual(names, ["ilk", "ikinci"])
    }

    func testResumeWorksForLocalVideos() throws {
        let positions = PlaybackPositionStore(database: database)

        try positions.save(kind: .local, key: "v1", position: 300, duration: 1200)

        XCTAssertEqual(try positions.resumePosition(kind: .local, key: "v1"), 300)
    }
}
