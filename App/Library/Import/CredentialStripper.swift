import Foundation

/// IPTV panels that generate M3U lists (`get.php?username=…&password=…`) put the
/// same username and password into every stream URL, as path segments
/// (`/live/<user>/<pass>/123.ts`) or query items. Before import, those are
/// swapped for placeholders, so the database never holds them; `fill` puts
/// them back at play time from the playlist URL kept in the Keychain.
enum CredentialStripper {
    static let marker = "torpido-cred:"
    private static let userToken = "__TORPIDO_USER__"
    private static let passToken = "__TORPIDO_PASS__"

    struct Credentials: Equatable {
        var username: String
        var password: String
    }

    /// The username and password a panel's playlist URL carries, if any.
    static func credentials(in playlistURL: URL) -> Credentials? {
        let items = URLComponents(url: playlistURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name.lowercased() == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        guard let username = value("username"), let password = value("password") else { return nil }
        return Credentials(username: username, password: password)
    }

    static func strip(_ entries: [PlaylistEntry], using credentials: Credentials?) -> [PlaylistEntry] {
        guard let credentials else { return entries }
        return entries.map { entry in
            var stripped = entry
            if let url = strip(entry.streamURL, using: credentials) { stripped.streamURL = url }
            return stripped
        }
    }

    /// Fills the placeholders back in. Returns nil when the URL had none.
    static func fill(_ stored: String, using credentials: Credentials) -> URL? {
        guard stored.hasPrefix(marker) else { return nil }
        let text = String(stored.dropFirst(marker.count))
            .replacingOccurrences(of: userToken, with: credentials.username)
            .replacingOccurrences(of: passToken, with: credentials.password)
        return URL(string: text)
    }

    private static func strip(_ url: URL, using credentials: Credentials) -> URL? {
        var text = url.absoluteString
        let pathPair = "/\(credentials.username)/\(credentials.password)/"
        var changed = false
        if text.contains(pathPair) {
            text = text.replacingOccurrences(of: pathPair, with: "/\(userToken)/\(passToken)/")
            changed = true
        }
        if var parts = URLComponents(string: text), let items = parts.queryItems {
            parts.queryItems = items.map { item in
                switch item.name.lowercased() {
                case "username" where item.value == credentials.username: changed = true; return URLQueryItem(name: item.name, value: userToken)
                case "password" where item.value == credentials.password: changed = true; return URLQueryItem(name: item.name, value: passToken)
                default: return item
                }
            }
            text = parts.string ?? text
        }
        return changed ? URL(string: marker + text) : nil
    }
}
