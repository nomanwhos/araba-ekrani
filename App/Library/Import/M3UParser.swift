import Foundation

/// One playable entry read from an M3U/M3U8 playlist.
struct PlaylistEntry: Equatable {
    var name: String
    var group: String?
    var logoURL: URL?
    var tvgID: String?
    var streamURL: URL
}

enum PlaylistError: Error, Equatable {
    /// The text does not start with #EXTM3U, so it is not a channel playlist.
    case notAPlaylist
}

/// Line-by-line M3U parser, so a 50 MB playlist can be read as it downloads.
///
/// Understands `#EXTM3U`, `#EXTINF:<duration> key="value" ...,<name>`,
/// `#EXTGRP:<group>`, blank lines, other `#` directives (ignored) and bare
/// URLs with no `#EXTINF` before them.
struct M3UParser {
    private var sawHeader = false
    private var pending: PendingInfo?

    private struct PendingInfo {
        var name: String
        var attributes: [String: String]
        var group: String?
    }

    /// Feeds one line. Returns an entry when the line completes one.
    mutating func consume(_ rawLine: String) throws -> PlaylistEntry? {
        let line = Self.clean(rawLine)
        guard !line.isEmpty else { return nil }

        if !sawHeader {
            guard line.uppercased().hasPrefix("#EXTM3U") else { throw PlaylistError.notAPlaylist }
            sawHeader = true
            return nil
        }

        if line.uppercased().hasPrefix("#EXTINF:") {
            pending = Self.parseInfo(String(line.dropFirst("#EXTINF:".count)))
            return nil
        }
        if line.uppercased().hasPrefix("#EXTGRP:") {
            let group = String(line.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespaces)
            // group-title on #EXTINF wins; #EXTGRP only fills a missing group.
            if !group.isEmpty, pending?.group == nil { pending?.group = group }
            return nil
        }
        if line.hasPrefix("#") { return nil }

        guard let url = URL(string: line), url.scheme != nil else {
            pending = nil
            return nil
        }
        defer { pending = nil }
        let info = pending
        let name = info?.name.isEmpty == false ? info!.name : Self.fallbackName(for: url)
        let attributes = info?.attributes ?? [:]
        return PlaylistEntry(
            name: name,
            group: Self.nonEmpty(attributes["group-title"]) ?? info?.group,
            logoURL: Self.nonEmpty(attributes["tvg-logo"]).flatMap(URL.init(string:)),
            tvgID: Self.nonEmpty(attributes["tvg-id"]),
            streamURL: url
        )
    }

    /// Parses a whole playlist held in memory (tests, small files).
    static func parse(_ text: String) throws -> [PlaylistEntry] {
        var parser = M3UParser()
        var entries: [PlaylistEntry] = []
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            if let entry = try parser.consume(String(line)) { entries.append(entry) }
        }
        guard parser.sawHeader else { throw PlaylistError.notAPlaylist }
        return entries
    }

    var hasSeenHeader: Bool { sawHeader }

    // MARK: - Helpers

    private static func clean(_ line: String) -> String {
        var text = line
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `-1 tvg-id="x" group-title="A, B",Channel name, with comma`
    /// The name is everything after the first comma that is outside quotes.
    private static func parseInfo(_ body: String) -> PendingInfo {
        var attributes: [String: String] = [:]
        var inQuotes = false
        var nameStart: String.Index?
        for index in body.indices {
            let char = body[index]
            if char == "\"" { inQuotes.toggle() }
            if char == ",", !inQuotes {
                nameStart = body.index(after: index)
                break
            }
        }
        let head = nameStart.map { String(body[..<body.index(before: $0)]) } ?? body
        let name = nameStart.map { String(body[$0...]).trimmingCharacters(in: .whitespaces) } ?? ""

        let pattern = #"([A-Za-z0-9_-]+)="([^"]*)""#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(head.startIndex..., in: head)
            for match in regex.matches(in: head, range: range) {
                guard let key = Range(match.range(at: 1), in: head),
                      let value = Range(match.range(at: 2), in: head) else { continue }
                attributes[head[key].lowercased()] = String(head[value])
            }
        }
        return PendingInfo(name: name, attributes: attributes, group: nil)
    }

    private static func fallbackName(for url: URL) -> String {
        let last = url.deletingPathExtension().lastPathComponent
        return last.isEmpty || last == "/" ? (url.host ?? url.absoluteString) : last
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
