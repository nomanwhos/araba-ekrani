import Foundation
import GRDB

/// Finds dead channels so Home can hide them, and measures how fast the live
/// ones answer (the latency badge). Polite on purpose: providers often allow
/// one or two connections and may ban an account that opens many.
/// - M3U sources only; Xtream accounts are never checked automatically.
/// - At most `perRunLimit` channels per run, `maxConcurrent` at a time.
/// - A channel is checked again only after `minInterval`.
/// - Each check asks for the first kilobyte, then hangs up.
struct HealthChecker {
    static let maxConcurrent = 4
    static let perRunLimit = 80
    static let minInterval: Int64 = 30 * 60
    static let timeout: TimeInterval = 3

    let database: AppDatabase
    var session: URLSession = .shared

    private struct Target: Sendable {
        var channelID: String
        var url: URL
    }

    private struct Outcome: Sendable {
        var channelID: String
        var isUp: Bool
        var latencyMs: Int?
    }

    /// Checks the channels that are due and records the result. Returns how many were checked.
    @discardableResult
    func run(now: Int64 = Clock.now()) async -> Int {
        guard let targets = try? await dueTargets(now: now), !targets.isEmpty else { return 0 }
        var outcomes: [Outcome] = []
        for start in stride(from: 0, to: targets.count, by: Self.maxConcurrent) {
            let batch = targets[start..<min(start + Self.maxConcurrent, targets.count)]
            await withTaskGroup(of: Outcome.self) { group in
                for target in batch { group.addTask { await check(target) } }
                for await outcome in group { outcomes.append(outcome) }
            }
        }
        try? await record(outcomes, at: now)
        return outcomes.count
    }

    private func dueTargets(now: Int64) async throws -> [Target] {
        try await database.reader.read { db in
            try Row.fetchAll(db, sql: """
                SELECT c.id, c.source_id, cs.url FROM channels c
                JOIN sources s ON s.id = c.source_id AND s.kind = 'm3u'
                JOIN channel_streams cs ON cs.channel_id = c.id AND cs.position = 0
                WHERE c.last_checked_at IS NULL OR c.last_checked_at <= ?
                ORDER BY c.last_checked_at IS NOT NULL, c.last_checked_at
                LIMIT ?
                """, arguments: [now - Self.minInterval, Self.perRunLimit])
        }
        .compactMap { row in
            // Stored URLs may hold credential placeholders; fill them in memory only.
            guard let stored = URL(string: row["url"]),
                  let url = StreamResolver(database: database).playableURL(for: stored, sourceID: row["source_id"]) else { return nil }
            return Target(channelID: row["id"], url: url)
        }
    }

    private func check(_ target: Target) async -> Outcome {
        var request = URLRequest(url: target.url, timeoutInterval: Self.timeout)
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        let started = Date()
        do {
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let isUp = (200..<400).contains(status)
            return Outcome(channelID: target.channelID, isUp: isUp,
                           latencyMs: isUp ? Int(Date().timeIntervalSince(started) * 1000) : nil)
        } catch {
            return Outcome(channelID: target.channelID, isUp: false, latencyMs: nil)
        }
    }

    private func record(_ outcomes: [Outcome], at now: Int64) async throws {
        try await database.writer.write { db in
            for outcome in outcomes {
                try db.execute(sql: "UPDATE channels SET health = ?, latency_ms = ?, last_checked_at = ? WHERE id = ?",
                               arguments: [outcome.isUp ? "ok" : "down", outcome.latencyMs, now, outcome.channelID])
            }
        }
    }
}
