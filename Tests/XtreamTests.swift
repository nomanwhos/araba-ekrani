import GRDB
import XCTest
@testable import Torpido

final class XtreamTests: XCTestCase {
    private let server = URL(string: "http://iptv.example:8080")!

    /// A panel that sends ids as numbers in one place and strings in another, as real panels do.
    private func panel(auth: Int = 1, status: String = "Active", formats: String = #"["m3u8","ts"]"#) -> URLSession {
        StubURLProtocol.session { request in
            guard request.queryValue("username") == "ali", request.queryValue("password") == "gizli" else {
                return .init(body: #"{"user_info":{"auth":0}}"#)
            }
            switch request.queryValue("action") {
            case nil:
                return .init(body: #"{"user_info":{"auth":\#(auth),"status":"\#(status)","allowed_output_formats":\#(formats)}}"#)
            case "get_live_categories":
                return .init(body: #"[{"category_id":"1","category_name":"Haber"},{"category_id":2,"category_name":"Spor"}]"#)
            case "get_live_streams":
                return .init(body: #"""
                [{"stream_id":101,"name":"Haber 24","stream_icon":"http://logo.example/h.png","epg_channel_id":"haber24","category_id":"1"},
                 {"stream_id":"202","name":"Spor HD","stream_icon":"","epg_channel_id":null,"category_id":2},
                 {"stream_id":303,"name":"","category_id":"99"}]
                """#)
            default:
                return nil
            }
        }
    }

    func testLoginPicksHLSWhenAllowed() async throws {
        let client = XtreamClient(server: server, username: "ali", password: "gizli", http: HTTPClient(session: panel()))

        let account = try await client.login()

        XCTAssertEqual(account.streamExtension, "m3u8")
    }

    func testLoginFallsBackToTSWhenHLSIsNotAllowed() async throws {
        let client = XtreamClient(server: server, username: "ali", password: "gizli",
                                  http: HTTPClient(session: panel(formats: #"["ts"]"#)))

        let account = try await client.login()

        XCTAssertEqual(account.streamExtension, "ts")
    }

    func testWrongPasswordIsAuthFailed() async {
        let client = XtreamClient(server: server, username: "ali", password: "yanlis", http: HTTPClient(session: panel()))

        do {
            _ = try await client.login()
            XCTFail("expected authFailed")
        } catch {
            XCTAssertEqual(error as? ServerError, .authFailed)
        }
    }

    func testExpiredAccountSaysSo() async {
        let client = XtreamClient(server: server, username: "ali", password: "gizli",
                                  http: HTTPClient(session: panel(status: "Expired")))

        do {
            _ = try await client.login()
            XCTFail("expected accountInactive")
        } catch {
            XCTAssertEqual(error as? ServerError, .accountInactive("Expired"))
        }
    }

    func testEntriesMapCategoriesLogosAndCredentialFreeURLs() async throws {
        let client = XtreamClient(server: server, username: "ali", password: "gizli", http: HTTPClient(session: panel()))

        let entries = try await client.playlistEntries(account: .init(streamExtension: "m3u8"))

        XCTAssertEqual(entries.map(\.name).prefix(2), ["Haber 24", "Spor HD"])
        XCTAssertTrue(entries[2].name.hasSuffix("303"), "an unnamed stream is named after its id")
        XCTAssertEqual(entries.map(\.group), ["Haber", "Spor", nil])
        XCTAssertEqual(entries[0].logoURL, URL(string: "http://logo.example/h.png"))
        XCTAssertNil(entries[1].logoURL)
        XCTAssertEqual(entries.map(\.streamURL.absoluteString),
                       ["xtream:live/101.m3u8", "xtream:live/202.m3u8", "xtream:live/303.m3u8"])
        XCTAssertEqual(entries[0].stableID, "xtream:101")
    }

    func testAddXtreamStoresNoPasswordAndResolvesStreamAtPlayTime() async throws {
        let database = try AppDatabase.empty()
        let service = SourceService(database: database, session: panel())

        let source = try await service.addXtream(serverText: "iptv.example:8080/", username: "ali", password: "gizli", name: "")
        defer { try? SourceStore(database: database).remove(source) }

        let leaked = try await database.reader.read { db in
            try Int.fetchOne(db, sql: """
                SELECT (SELECT COUNT(*) FROM sources WHERE url LIKE '%gizli%')
                     + (SELECT COUNT(*) FROM channel_streams WHERE url LIKE '%gizli%')
                """)
        }
        XCTAssertEqual(leaked, 0, "the password must never reach the database")
        XCTAssertEqual(source.url, "http://iptv.example:8080")
        XCTAssertEqual(source.name, "iptv.example")

        let channel = try await database.reader.read { try Channel.filter(Column("name") == "Haber 24").fetchOne($0) }
        let stored = try await database.reader.read { db in try LibraryQueries.firstStreamURL(for: XCTUnwrap(channel), db) }
        let playable = StreamResolver(database: database).playableURL(for: try XCTUnwrap(stored), sourceID: source.id)
        XCTAssertEqual(playable?.absoluteString, "http://iptv.example:8080/live/ali/gizli/101.m3u8")
    }

    func testFavouriteSurvivesAChannelMovingCategory() throws {
        var maker = StableKeyMaker()
        var later = StableKeyMaker()
        let before = PlaylistEntry(name: "Haber 24", group: "Haber", logoURL: nil, tvgID: nil,
                                   streamURL: URL(string: "xtream:live/101.m3u8")!, stableID: "xtream:101")
        var after = before
        after.group = "Ulusal"

        XCTAssertEqual(maker.key(for: before), later.key(for: after))
    }

    func testServerAddressIsNormalised() {
        XCTAssertEqual(HTTPClient.serverURL(from: " sunucu.com:8080/ ")?.absoluteString, "http://sunucu.com:8080")
        XCTAssertEqual(HTTPClient.serverURL(from: "https://s.example")?.absoluteString, "https://s.example")
        XCTAssertNil(HTTPClient.serverURL(from: "ftp://s.example"))
        XCTAssertNil(HTTPClient.serverURL(from: ""))
    }
}
