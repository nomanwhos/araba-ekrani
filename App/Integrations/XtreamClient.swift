import Foundation

/// The owner's IPTV provider, through its Xtream Codes `player_api.php`.
/// Only live TV for now (categories and streams).
struct XtreamClient {
    struct Account: Equatable {
        /// "m3u8" when the panel allows HLS output, otherwise "ts".
        var streamExtension: String
    }

    struct Category: Decodable, Equatable {
        var id: String
        var name: String

        enum CodingKeys: String, CodingKey { case id = "category_id", name = "category_name" }

        init(id: String, name: String) {
            self.id = id
            self.name = name
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(FlexibleString.self, forKey: .id).value
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        }
    }

    struct LiveStream: Decodable, Equatable {
        var streamID: String
        var name: String
        var icon: String?
        var epgID: String?
        var categoryID: String?

        enum CodingKeys: String, CodingKey {
            case streamID = "stream_id", name, icon = "stream_icon", epgID = "epg_channel_id", categoryID = "category_id"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            streamID = try c.decode(FlexibleString.self, forKey: .streamID).value
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            icon = try? c.decodeIfPresent(String.self, forKey: .icon)
            epgID = try? c.decodeIfPresent(String.self, forKey: .epgID)
            categoryID = (try? c.decodeIfPresent(FlexibleString.self, forKey: .categoryID))?.value
        }
    }

    private struct LoginResponse: Decodable {
        struct UserInfo: Decodable {
            var auth: FlexibleString?
            var status: String?
            var allowedOutputFormats: [String]?

            enum CodingKeys: String, CodingKey { case auth, status, allowedOutputFormats = "allowed_output_formats" }
        }

        var userInfo: UserInfo?

        enum CodingKeys: String, CodingKey { case userInfo = "user_info" }
    }

    let server: URL
    let username: String
    let password: String
    var http = HTTPClient()

    func login() async throws -> Account {
        let response = try await http.get(apiURL(action: nil), as: LoginResponse.self)
        guard let info = response.userInfo, info.auth?.value == "1" else { throw ServerError.authFailed }
        if let status = info.status, status.lowercased() != "active" { throw ServerError.accountInactive(status) }
        let formats = info.allowedOutputFormats ?? []
        return Account(streamExtension: formats.isEmpty || formats.contains("m3u8") ? "m3u8" : "ts")
    }

    func liveCategories() async throws -> [Category] {
        try await http.get(apiURL(action: "get_live_categories"), as: [Category].self)
    }

    func liveStreams() async throws -> [LiveStream] {
        try await http.get(apiURL(action: "get_live_streams"), as: [LiveStream].self)
    }

    /// Playlist entries for the importer. Stream URLs are stored as
    /// `xtream:live/<id>.<ext>` so no credentials reach the database;
    /// `StreamResolver` builds the real URL at play time.
    func playlistEntries(account: Account) async throws -> [PlaylistEntry] {
        async let categories = liveCategories()
        async let streams = liveStreams()
        let names = Dictionary(try await categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return try await streams.compactMap { stream in
            guard let url = URL(string: "xtream:live/\(stream.streamID).\(account.streamExtension)") else { return nil }
            return PlaylistEntry(
                name: stream.name.isEmpty ? String(localized: "Kanal \(stream.streamID)") : stream.name,
                group: stream.categoryID.flatMap { names[$0] },
                logoURL: stream.icon.flatMap { $0.isEmpty ? nil : URL(string: $0) },
                tvgID: stream.epgID.flatMap { $0.isEmpty ? nil : $0 },
                streamURL: url,
                stableID: "xtream:\(stream.streamID)"
            )
        }
    }

    /// `<server>/live/<user>/<password>/<id>.<ext>`: built only at play time.
    func liveURL(path: String) -> URL {
        server.appendingPathComponent("live")
            .appendingPathComponent(username)
            .appendingPathComponent(password)
            .appendingPathComponent(path)
    }

    private func apiURL(action: String?) -> URL {
        var parts = URLComponents(url: server.appendingPathComponent("player_api.php"), resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "username", value: username), URLQueryItem(name: "password", value: password)]
        if let action { parts.queryItems?.append(URLQueryItem(name: "action", value: action)) }
        return parts.url!
    }
}
