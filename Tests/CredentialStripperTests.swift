import GRDB
import XCTest
@testable import Torpido

final class CredentialStripperTests: XCTestCase {
    private let playlist = URL(string: "http://panel.example:8080/get.php?username=ali&password=gizli99&type=m3u_plus")!

    private func entry(_ url: String) -> PlaylistEntry {
        PlaylistEntry(name: "K", group: nil, logoURL: nil, tvgID: nil, streamURL: URL(string: url)!)
    }

    func testReadsCredentialsFromThePanelURL() {
        XCTAssertEqual(CredentialStripper.credentials(in: playlist), .init(username: "ali", password: "gizli99"))
        XCTAssertNil(CredentialStripper.credentials(in: URL(string: "https://lists.example/tr.m3u")!))
    }

    func testStripsPathCredentialsAndFillsThemBack() throws {
        let creds = try XCTUnwrap(CredentialStripper.credentials(in: playlist))

        let stored = CredentialStripper.strip([entry("http://panel.example:8080/live/ali/gizli99/123.ts")], using: creds)[0].streamURL

        XCTAssertFalse(stored.absoluteString.contains("gizli99"))
        XCTAssertTrue(stored.absoluteString.hasPrefix(CredentialStripper.marker))
        XCTAssertEqual(CredentialStripper.fill(stored.absoluteString, using: creds)?.absoluteString,
                       "http://panel.example:8080/live/ali/gizli99/123.ts")
    }

    func testStripsQueryCredentials() throws {
        let creds = try XCTUnwrap(CredentialStripper.credentials(in: playlist))

        let stored = CredentialStripper.strip([entry("http://panel.example/play?username=ali&password=gizli99&id=7")], using: creds)[0]

        XCTAssertFalse(stored.streamURL.absoluteString.contains("gizli99"))
        XCTAssertEqual(CredentialStripper.fill(stored.streamURL.absoluteString, using: creds)?.absoluteString,
                       "http://panel.example/play?username=ali&password=gizli99&id=7")
    }

    func testLeavesUnrelatedURLsAlone() throws {
        let creds = try XCTUnwrap(CredentialStripper.credentials(in: playlist))
        let other = "http://cdn.example/news/master.m3u8"

        XCTAssertEqual(CredentialStripper.strip([entry(other)], using: creds)[0].streamURL.absoluteString, other)
    }

    func testAddM3UStoresNoPasswordAndStillPlays() async throws {
        let database = try AppDatabase.empty()
        let session = StubURLProtocol.session { request in
            guard request.url?.path == "/get.php" else { return nil }
            return .init(body: """
            #EXTM3U
            #EXTINF:-1 group-title="Haber",Haber 24
            http://panel.example:8080/live/ali/gizli99/123.ts
            """)
        }

        let source = try await SourceService(database: database, session: session)
            .addM3U(urlText: playlist.absoluteString, name: "Panel")
        defer { try? SourceStore(database: database).remove(source) }

        let leaked = try await database.reader.read {
            try Int.fetchOne($0, sql: """
                SELECT (SELECT COUNT(*) FROM channel_streams WHERE url LIKE '%gizli99%')
                     + (SELECT COUNT(*) FROM sources WHERE url LIKE '%gizli99%')
                """)
        }
        XCTAssertEqual(leaked, 0)
        let stored = try await database.reader.read { try String.fetchOne($0, sql: "SELECT url FROM channel_streams") }
        let playable = StreamResolver(database: database).playableURL(for: try XCTUnwrap(stored.flatMap(URL.init(string:))),
                                                                     sourceID: source.id)
        XCTAssertEqual(playable?.absoluteString, "http://panel.example:8080/live/ali/gizli99/123.ts")
    }
}
