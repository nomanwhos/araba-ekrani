import Foundation

/// Why a media-server request failed, in words the owner can act on.
/// Messages never include the URL: Xtream and Jellyfin URLs can carry credentials.
enum ServerError: LocalizedError, Equatable {
    case invalidServer
    case unreachable
    case authFailed
    case accountInactive(String)
    case http(Int)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidServer: "Sunucu adresi geçersiz. http:// ya da https:// ile başlayan adresi yazın (örn. http://sunucu.com:8080)."
        case .unreachable: "Sunucuya ulaşılamadı. Adresi, portu ve internet bağlantınızı kontrol edin."
        case .authFailed: "Kullanıcı adı ya da şifre yanlış."
        case .accountInactive(let status): "Hesap etkin değil (durum: \(status)). Sağlayıcınızla görüşün."
        case .http(let code): "Sunucu bir hata döndürdü (\(code))."
        case .unexpectedResponse: "Sunucunun yanıtı anlaşılamadı. Bu bir Xtream ya da Jellyfin sunucusu mu?"
        }
    }
}

/// Thin JSON-over-HTTP helper shared by the integrations.
struct HTTPClient {
    var session: URLSession = .shared
    var timeout: TimeInterval = 20

    func get<T: Decodable>(_ url: URL, headers: [String: String] = [:], as type: T.Type) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return try await send(request, as: type)
    }

    func post<T: Decodable>(_ url: URL, json: some Encodable, headers: [String: String] = [:], as type: T.Type) async throws -> T {
        try await send(postRequest(url, json: json, headers: headers), as: type)
    }

    /// POST that only needs to succeed (progress reports).
    func post(_ url: URL, json: some Encodable, headers: [String: String] = [:]) async throws {
        _ = try await data(for: postRequest(url, json: json, headers: headers))
    }

    private func postRequest(_ url: URL, json: some Encodable, headers: [String: String]) throws -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(json)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let body = try await data(for: request)
        do {
            return try JSONDecoder().decode(T.self, from: body)
        } catch {
            throw ServerError.unexpectedResponse
        }
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (body, response): (Data, URLResponse)
        do {
            (body, response) = try await session.data(for: request)
        } catch {
            throw ServerError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw ServerError.unexpectedResponse }
        switch http.statusCode {
        case 200..<300: return body
        case 401, 403: throw ServerError.authFailed
        default: throw ServerError.http(http.statusCode)
        }
    }

    /// Accepts "sunucu.com:8080", "http://sunucu.com:8080/" and similar; drops trailing slashes.
    static func serverURL(from text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if !trimmed.contains("://") { trimmed = "http://" + trimmed }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), url.host?.isEmpty == false else { return nil }
        return url
    }
}

/// Decodes a JSON value that panels send as a string in one place and a number in another.
struct FlexibleString: Decodable, Equatable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            value = text
        } else if let number = try? container.decode(Int.self) {
            value = String(number)
        } else if let number = try? container.decode(Double.self) {
            value = String(Int(number))
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a string or number")
        }
    }
}
