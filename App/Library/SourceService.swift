import Foundation

/// Why adding or refreshing a source failed, in words the owner can act on.
enum SourceError: LocalizedError, Equatable {
    case invalidURL
    case downloadFailed(status: Int?)
    case notAPlaylist
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Bu bir bağlantı değil. http:// ya da https:// ile başlayan adresi yapıştırın."
        case .downloadFailed(let status?):
            "Liste indirilemedi (sunucu \(status) döndürdü). Bağlantının süresi dolmuş olabilir."
        case .downloadFailed(nil):
            "Liste indirilemedi. İnternet bağlantınızı ve adresi kontrol edin."
        case .notAPlaylist:
            "Bu adres bir kanal listesi değil: içeriği #EXTM3U ile başlamıyor."
        case .empty:
            "Liste indirildi ama içinde oynatılabilir kanal yok."
        }
    }
}

/// Adds and refreshes sources: M3U playlists (streamed download), Xtream
/// accounts and Jellyfin servers (official APIs, the owner's own credentials).
struct SourceService {
    let database: AppDatabase
    var session: URLSession = .shared

    private var http: HTTPClient { HTTPClient(session: session) }

    /// Validates, creates the source, downloads and imports it. On a failed
    /// first download the source is not kept.
    func addM3U(urlText: String, name: String) async throws -> Source {
        guard let url = Self.playlistURL(from: urlText) else { throw SourceError.invalidURL }
        let entries = CredentialStripper.strip(try await download(url), using: CredentialStripper.credentials(in: url))
        let store = SourceStore(database: database)
        let source = try store.createM3U(url: url, name: name.isEmpty ? Self.defaultName(for: url) : name)
        return try importOrRollBack(entries, into: source)
    }

    /// Signs in to the owner's Xtream account and imports its live channels.
    func addXtream(serverText: String, username: String, password: String, name: String) async throws -> Source {
        guard let server = HTTPClient.serverURL(from: serverText) else { throw ServerError.invalidServer }
        let user = username.trimmingCharacters(in: .whitespaces)
        guard !user.isEmpty, !password.isEmpty else { throw ServerError.authFailed }
        let client = XtreamClient(server: server, username: user, password: password, http: http)
        let entries = try await client.playlistEntries(account: client.login())
        guard !entries.isEmpty else { throw SourceError.empty }
        let store = SourceStore(database: database)
        let source = try store.createXtream(server: server, username: user, password: password,
                                            name: name.isEmpty ? (server.host ?? "Xtream") : name)
        return try importOrRollBack(entries, into: source)
    }

    /// Signs in to the owner's Jellyfin server; the library is browsed live, not imported.
    func addJellyfin(serverText: String, username: String, password: String, name: String) async throws -> Source {
        guard let server = HTTPClient.serverURL(from: serverText) else { throw ServerError.invalidServer }
        let user = username.trimmingCharacters(in: .whitespaces)
        guard !user.isEmpty else { throw ServerError.authFailed }
        var client = JellyfinClient(server: server, http: http)
        let session = try await client.signIn(username: user, password: password)
        client.session = session
        _ = try await client.libraries()
        return try SourceStore(database: database).createJellyfin(server: server, username: user, session: session,
                                                                  name: name.isEmpty ? (server.host ?? "Jellyfin") : name)
    }

    /// Re-downloads an existing source; on failure the old channels stay and the error is recorded.
    func refresh(_ source: Source) async throws {
        let store = SourceStore(database: database)
        do {
            switch source.kind {
            case .m3u:
                guard let url = store.playlistURL(for: source) else { throw SourceError.invalidURL }
                let entries = CredentialStripper.strip(try await download(url), using: CredentialStripper.credentials(in: url))
                _ = try PlaylistImporter(database: database).importEntries(entries, into: source.id)
            case .xtream:
                guard var client = store.xtreamClient(for: source) else { throw ServerError.authFailed }
                client.http = http
                let entries = try await client.playlistEntries(account: client.login())
                _ = try PlaylistImporter(database: database).importEntries(entries, into: source.id)
            case .jellyfin:
                guard var client = store.jellyfinClient(for: source) else { throw ServerError.authFailed }
                client.http = http
                _ = try await client.libraries()
                try store.markRefreshed(source.id)
            case .emby, .plex:
                break
            }
        } catch {
            try store.markFailed(source.id, message: error.localizedDescription)
            throw error
        }
    }

    private func importOrRollBack(_ entries: [PlaylistEntry], into source: Source) throws -> Source {
        do {
            _ = try PlaylistImporter(database: database).importEntries(entries, into: source.id)
            return source
        } catch {
            try? SourceStore(database: database).remove(source)
            throw error
        }
    }

    private func download(_ url: URL) async throws -> [PlaylistEntry] {
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(from: url)
        } catch {
            throw SourceError.downloadFailed(status: nil)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SourceError.downloadFailed(status: http.statusCode)
        }
        var parser = M3UParser()
        var entries: [PlaylistEntry] = []
        do {
            for try await line in bytes.lines {
                if let entry = try parser.consume(line) { entries.append(entry) }
            }
        } catch PlaylistError.notAPlaylist {
            throw SourceError.notAPlaylist
        } catch {
            throw SourceError.downloadFailed(status: nil)
        }
        guard parser.hasSeenHeader else { throw SourceError.notAPlaylist }
        guard !entries.isEmpty else { throw SourceError.empty }
        return entries
    }

    static func playlistURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), url.host != nil else { return nil }
        return url
    }

    static func defaultName(for url: URL) -> String {
        url.host ?? "Kanal listesi"
    }
}
