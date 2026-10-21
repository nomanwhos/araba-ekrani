import Foundation

/// The owner's own Jellyfin server, through its public REST API.
/// Video is requested as HLS (H.264/AAC) so the server transcodes MKV/HEVC/DTS
/// into something AVPlayer always plays.
struct JellyfinClient {
    struct Session: Codable, Equatable {
        var token: String
        var userID: String
    }

    struct Item: Decodable, Identifiable, Equatable, Hashable {
        var id: String
        var name: String
        var type: String
        var collectionType: String?
        var indexNumber: Int?
        var parentIndexNumber: Int?
        var runTimeTicks: Int64?
        var resumeTicks: Int64?
        var seriesName: String?

        enum CodingKeys: String, CodingKey {
            case id = "Id", name = "Name", type = "Type", collectionType = "CollectionType"
            case indexNumber = "IndexNumber", parentIndexNumber = "ParentIndexNumber"
            case runTimeTicks = "RunTimeTicks", userData = "UserData", seriesName = "SeriesName"
        }

        private struct UserData: Decodable {
            var playbackPositionTicks: Int64?
            enum CodingKeys: String, CodingKey { case playbackPositionTicks = "PlaybackPositionTicks" }
        }

        init(id: String, name: String, type: String, collectionType: String? = nil, indexNumber: Int? = nil,
             parentIndexNumber: Int? = nil, runTimeTicks: Int64? = nil, resumeTicks: Int64? = nil, seriesName: String? = nil) {
            self.id = id; self.name = name; self.type = type; self.collectionType = collectionType
            self.indexNumber = indexNumber; self.parentIndexNumber = parentIndexNumber
            self.runTimeTicks = runTimeTicks; self.resumeTicks = resumeTicks; self.seriesName = seriesName
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
            collectionType = try c.decodeIfPresent(String.self, forKey: .collectionType)
            indexNumber = try c.decodeIfPresent(Int.self, forKey: .indexNumber)
            parentIndexNumber = try c.decodeIfPresent(Int.self, forKey: .parentIndexNumber)
            runTimeTicks = try c.decodeIfPresent(Int64.self, forKey: .runTimeTicks)
            resumeTicks = try c.decodeIfPresent(UserData.self, forKey: .userData)?.playbackPositionTicks
            seriesName = try c.decodeIfPresent(String.self, forKey: .seriesName)
        }

        /// Movies, episodes and plain videos play; everything else is a folder to open.
        var isPlayable: Bool { ["Movie", "Episode", "Video", "MusicVideo"].contains(type) }

        var resumeSeconds: Double? {
            guard let ticks = resumeTicks, ticks > 0 else { return nil }
            return Double(ticks) / Double(JellyfinClient.ticksPerSecond)
        }

        /// "S2 · B5 · Bölüm adı" for episodes, the name otherwise.
        var displayTitle: String {
            guard type == "Episode" else { return name }
            let season = parentIndexNumber.map { "S\($0)" }
            let episode = indexNumber.map { "B\($0)" }
            return ([season, episode].compactMap { $0 } + [name]).joined(separator: " · ")
        }
    }

    private struct ItemsResponse: Decodable {
        var items: [Item]
        enum CodingKeys: String, CodingKey { case items = "Items" }
    }

    private struct AuthRequest: Encodable {
        var username: String
        var pw: String
        enum CodingKeys: String, CodingKey { case username = "Username", pw = "Pw" }
    }

    private struct AuthResponse: Decodable {
        struct User: Decodable {
            var id: String
            enum CodingKeys: String, CodingKey { case id = "Id" }
        }
        var accessToken: String
        var user: User
        enum CodingKeys: String, CodingKey { case accessToken = "AccessToken", user = "User" }
    }

    struct PlaybackReport: Encodable {
        var itemID: String
        var mediaSourceID: String
        var playSessionID: String
        var positionTicks: Int64
        var isPaused: Bool

        enum CodingKeys: String, CodingKey {
            case itemID = "ItemId", mediaSourceID = "MediaSourceId", playSessionID = "PlaySessionId"
            case positionTicks = "PositionTicks", isPaused = "IsPaused"
        }
    }

    static let ticksPerSecond: Int64 = 10_000_000

    let server: URL
    var session: Session?
    var http = HTTPClient()

    static var deviceID: String {
        let key = "TorpidoDeviceID"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    private var headers: [String: String] {
        var value = #"MediaBrowser Client="Torpido", Device="iPhone", DeviceId="\#(Self.deviceID)", Version="0.1.0""#
        if let token = session?.token { value += #", Token="\#(token)""# }
        return ["Authorization": value]
    }

    func signIn(username: String, password: String) async throws -> Session {
        let response = try await http.post(server.appendingPathComponent("Users/AuthenticateByName"),
                                           json: AuthRequest(username: username, pw: password),
                                           headers: headers, as: AuthResponse.self)
        return Session(token: response.accessToken, userID: response.user.id)
    }

    /// The user's libraries (Filmler, Diziler...).
    func libraries() async throws -> [Item] {
        guard let session else { throw ServerError.authFailed }
        return try await http.get(server.appendingPathComponent("Users/\(session.userID)/Views"),
                                  headers: headers, as: ItemsResponse.self).items
    }

    /// Children of a library, series or season, in season/episode then name order.
    func children(of parentID: String) async throws -> [Item] {
        guard let session else { throw ServerError.authFailed }
        var parts = URLComponents(url: server.appendingPathComponent("Users/\(session.userID)/Items"), resolvingAgainstBaseURL: false)!
        parts.queryItems = [
            URLQueryItem(name: "ParentId", value: parentID),
            URLQueryItem(name: "SortBy", value: "ParentIndexNumber,IndexNumber,SortName"),
            URLQueryItem(name: "Fields", value: "RunTimeTicks"),
        ]
        return try await http.get(parts.url!, headers: headers, as: ItemsResponse.self).items
    }

    /// HLS stream for one item. Carries the token, so it is built only at play time.
    func playbackURL(itemID: String, playSessionID: String) -> URL? {
        guard let session else { return nil }
        var parts = URLComponents(url: server.appendingPathComponent("Videos/\(itemID)/master.m3u8"), resolvingAgainstBaseURL: false)
        parts?.queryItems = [
            URLQueryItem(name: "MediaSourceId", value: itemID),
            URLQueryItem(name: "VideoCodec", value: "h264"),
            URLQueryItem(name: "AudioCodec", value: "aac"),
            URLQueryItem(name: "TranscodingMaxAudioChannels", value: "2"),
            URLQueryItem(name: "DeviceId", value: Self.deviceID),
            URLQueryItem(name: "PlaySessionId", value: playSessionID),
            URLQueryItem(name: "api_key", value: session.token),
        ]
        return parts?.url
    }

    enum ReportKind: String {
        case started = "Sessions/Playing", progress = "Sessions/Playing/Progress", stopped = "Sessions/Playing/Stopped"
    }

    /// Tells the server where playback is, so resume works in every Jellyfin app.
    func report(_ kind: ReportKind, _ report: PlaybackReport) async throws {
        try await http.post(server.appendingPathComponent(kind.rawValue), json: report, headers: headers)
    }
}
