import Foundation

/// Folds text for matching: Turkish-aware lowercase, dotless ı treated as i,
/// accents removed, inner whitespace collapsed. "İSTANBUL Çocuk  TV" -> "istanbul cocuk tv".
enum TurkishFold {
    private static let turkish = Locale(identifier: "tr_TR")

    static func fold(_ text: String) -> String {
        text.lowercased(with: turkish)
            .replacingOccurrences(of: "ı", with: "i")
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: turkish)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

/// Gives every playlist entry a key that stays the same when the playlist is
/// downloaded again, so favourites and resume positions survive a refresh.
///
/// Prefers tvg-id, falls back to the name; always scoped by group. Repeats of
/// the same key in one playlist get "#2", "#3"... in playlist order.
struct StableKeyMaker {
    private var seen: [String: Int] = [:]

    mutating func key(for entry: PlaylistEntry) -> String {
        let identity = entry.tvgID.map { "tvg:" + TurkishFold.fold($0) } ?? "name:" + TurkishFold.fold(entry.name)
        let base = identity + "|" + TurkishFold.fold(entry.group ?? "")
        let count = (seen[base] ?? 0) + 1
        seen[base] = count
        return count == 1 ? base : "\(base)#\(count)"
    }
}
