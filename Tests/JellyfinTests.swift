import XCTest
@testable import Torpido

final class JellyfinTests: XCTestCase {
    private let server = URL(string: "http://192.168.1.10:8096")!

    private func jellyfin() -> URLSession {
        StubURLProtocol.session { request in
            let path = request.url?.path ?? ""
            switch path {
            case "/Users/AuthenticateByName":
                let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
                guard body.contains(#""Pw":"gizli""#) else { return .init(status: 401, body: "") }
                return .init(body: #"{"AccessToken":"tok123","User":{"Id":"u1"}}"#)
            case "/Users/u1/Views":
                guard request.value(forHTTPHeaderField: "Authorization")?.contains(#"Token="tok123""#) == true else {
                    return .init(status: 401, body: "")
                }
                return .init(body: #"{"Items":[{"Id":"lib1","Name":"Filmler","Type":"CollectionFolder","CollectionType":"movies"}]}"#)
            case "/Users/u1/Items":
                return .init(body: #"""
                {"Items":[
                  {"Id":"m1","Name":"Uzun Yol","Type":"Movie","RunTimeTicks":66000000000,"UserData":{"PlaybackPositionTicks":22800000000}},
                  {"Id":"e1","Name":"Başlangıç","Type":"Episode","IndexNumber":5,"ParentIndexNumber":2},
                  {"Id":"s1","Name":"Bir Dizi","Type":"Series"}
                ]}
                """#)
            case "/Sessions/Playing/Progress":
                return .init(status: 204, body: "")
            default:
                return nil
            }
        }
    }

    func testSignInReturnsTokenAndUser() async throws {
        let client = JellyfinClient(server: server, http: HTTPClient(session: jellyfin()))

        let session = try await client.signIn(username: "ali", password: "gizli")

        XCTAssertEqual(session, .init(token: "tok123", userID: "u1"))
    }

    func testWrongPasswordIsAuthFailed() async {
        let client = JellyfinClient(server: server, http: HTTPClient(session: jellyfin()))

        do {
            _ = try await client.signIn(username: "ali", password: "yanlis")
            XCTFail("expected authFailed")
        } catch {
            XCTAssertEqual(error as? ServerError, .authFailed)
        }
    }

    func testChildrenDecodeTypesResumeAndTitles() async throws {
        let client = JellyfinClient(server: server, session: .init(token: "tok123", userID: "u1"),
                                    http: HTTPClient(session: jellyfin()))

        let items = try await client.children(of: "lib1")

        XCTAssertEqual(items.map(\.isPlayable), [true, true, false])
        XCTAssertEqual(items[0].resumeSeconds, 2280)
        XCTAssertEqual(items[1].displayTitle, "S2 · B5 · Başlangıç")
        XCTAssertEqual(StubURLProtocol.requests.last?.queryValue("ParentId"), "lib1")
    }

    func testPlaybackURLAsksForHLSAndCarriesTheToken() throws {
        let client = JellyfinClient(server: server, session: .init(token: "tok123", userID: "u1"))

        let url = try XCTUnwrap(client.playbackURL(itemID: "m1", playSessionID: "p1"))
        let request = URLRequest(url: url)

        XCTAssertEqual(url.path, "/Videos/m1/master.m3u8")
        XCTAssertEqual(request.queryValue("VideoCodec"), "h264")
        XCTAssertEqual(request.queryValue("api_key"), "tok123")
        XCTAssertEqual(request.queryValue("PlaySessionId"), "p1")
    }

    func testProgressReportSendsTicks() async throws {
        let client = JellyfinClient(server: server, session: .init(token: "tok123", userID: "u1"),
                                    http: HTTPClient(session: jellyfin()))

        try await client.report(.progress, .init(itemID: "m1", mediaSourceID: "m1", playSessionID: "p1",
                                                 positionTicks: 600 * JellyfinClient.ticksPerSecond, isPaused: false))

        let body = String(decoding: StubURLProtocol.requests.last?.httpBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(body.contains(#""PositionTicks":6000000000"#), body)
    }

    func testAddJellyfinKeepsTheTokenInTheKeychainOnly() async throws {
        let database = try AppDatabase.empty()

        let source = try await SourceService(database: database, session: jellyfin())
            .addJellyfin(serverText: "192.168.1.10:8096", username: "ali", password: "gizli", name: "Ev sunucusu")
        defer { try? SourceStore(database: database).remove(source) }

        let leaked = try await database.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sources WHERE url LIKE '%tok123%' OR username LIKE '%tok123%'")
        }
        XCTAssertEqual(leaked, 0)
        XCTAssertEqual(source.kind, .jellyfin)
        XCTAssertEqual(SourceStore(database: database).jellyfinClient(for: source)?.session?.token, "tok123")
    }
}
