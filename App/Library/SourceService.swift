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

/// Downloads a playlist as it streams in, then imports it.
struct SourceService {
    let database: AppDatabase
    var session: URLSession = .shared

    /// Validates, creates the source, downloads and imports it. On a failed
    /// first download the source is not kept.
    func addM3U(urlText: String, name: String) async throws -> Source {
        guard let url = Self.playlistURL(from: urlText) else { throw SourceError.invalidURL }
        let entries = try await download(url)
        let store = SourceStore(database: database)
        let source = try store.createM3U(url: url, name: name.isEmpty ? Self.defaultName(for: url) : name)
        do {
            _ = try PlaylistImporter(database: database).importEntries(entries, into: source.id)
        } catch {
            try? store.remove(source)
            throw error
        }
        return source
    }

    /// Re-downloads an existing source; on failure the old channels stay and the error is recorded.
    func refresh(_ source: Source) async throws {
        guard let url = SourceStore(database: database).playlistURL(for: source) else { throw SourceError.invalidURL }
        do {
            let entries = try await download(url)
            _ = try PlaylistImporter(database: database).importEntries(entries, into: source.id)
        } catch {
            try SourceStore(database: database).markFailed(source.id, message: error.localizedDescription)
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
