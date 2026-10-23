import GRDB
import XCTest
@testable import Torpido

final class HealthCheckerTests: XCTestCase {
    private func network() -> URLSession {
        StubURLProtocol.session { request in
            switch request.url?.host {
            case "up.example": return .init(status: 206, body: "x")
            case "missing.example": return .init(status: 404, body: "")
            default: return nil // connection refused
            }
        }
    }

    private func entry(_ name: String, _ host: String) -> PlaylistEntry {
        PlaylistEntry(name: name, group: "G", logoURL: nil, tvgID: nil, streamURL: URL(string: "http://\(host)/live.m3u8")!)
    }

    private func health(_ database: AppDatabase) throws -> [String: String] {
        try database.reader.read { db in
            Dictionary(uniqueKeysWithValues: try Row.fetchAll(db, sql: "SELECT name, health FROM channels").map {
                ($0["name"] as String, $0["health"] as String)
            })
        }
    }

    func testMarksLiveAndDeadChannels() async throws {
        let database = try AppDatabase.empty()
        let source = try SourceStore(database: database).createM3U(url: URL(string: "http://p.example/l.m3u")!, name: "T")
        _ = try PlaylistImporter(database: database).importEntries([
            entry("Açık", "up.example"), entry("Yok", "missing.example"), entry("Kapalı", "closed.example"),
        ], into: source.id)

        let checked = await HealthChecker(database: database, session: network()).run(now: 10_000)

        XCTAssertEqual(checked, 3)
        XCTAssertEqual(try health(database), ["Açık": "ok", "Yok": "down", "Kapalı": "down"])
        let latency = try await database.reader.read {
            try Int.fetchOne($0, sql: "SELECT latency_ms FROM channels WHERE name = 'Açık'")
        }
        XCTAssertNotNil(latency)
        XCTAssertEqual(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "Range"), "bytes=0-1023")
    }

    func testDoesNotRecheckWithinTheInterval() async throws {
        let database = try AppDatabase.empty()
        let source = try SourceStore(database: database).createM3U(url: URL(string: "http://p.example/l.m3u")!, name: "T")
        _ = try PlaylistImporter(database: database).importEntries([entry("Açık", "up.example")], into: source.id)
        let checker = HealthChecker(database: database, session: network())

        let first = await checker.run(now: 10_000)
        let tooSoon = await checker.run(now: 10_000 + HealthChecker.minInterval - 1)
        let later = await checker.run(now: 10_000 + HealthChecker.minInterval)

        XCTAssertEqual([first, tooSoon, later], [1, 0, 1])
    }

    func testNeverChecksXtreamChannels() async throws {
        let database = try AppDatabase.empty()
        let source = try SourceStore(database: database)
            .createXtream(server: URL(string: "http://iptv.example")!, username: "ali", password: "gizli", name: "X")
        defer { try? SourceStore(database: database).remove(source) }
        _ = try PlaylistImporter(database: database).importEntries([
            PlaylistEntry(name: "Haber", group: "G", logoURL: nil, tvgID: nil,
                          streamURL: URL(string: "xtream:live/1.m3u8")!, stableID: "xtream:1"),
        ], into: source.id)

        let checked = await HealthChecker(database: database, session: network()).run(now: 10_000)

        XCTAssertEqual(checked, 0)
        XCTAssertEqual(try health(database), ["Haber": "unknown"])
    }

    func testChecksAtMostThePerRunLimit() async throws {
        let database = try AppDatabase.empty()
        let source = try SourceStore(database: database).createM3U(url: URL(string: "http://p.example/l.m3u")!, name: "T")
        _ = try PlaylistImporter(database: database).importEntries(
            (0..<(HealthChecker.perRunLimit + 5)).map { entry("Kanal \($0)", "up.example") }, into: source.id)

        let checked = await HealthChecker(database: database, session: network()).run(now: 10_000)

        XCTAssertEqual(checked, HealthChecker.perRunLimit)
    }
}
