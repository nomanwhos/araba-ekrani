import Foundation
import GRDB

/// Torpido's on-device database. The schema lives in `replica/schema.sql`
/// (bundled as `schema.sql`) so the plan and the app can never disagree.
final class AppDatabase {
    let writer: any DatabaseWriter

    var reader: any DatabaseReader { writer }

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: try schemaV1())
        }
        // v2: search uses a Turkish-folded column instead of FTS5. unicode61 cannot
        // fold dotless ı to i, and the FTS table keyed on the implicit rowid of a
        // TEXT-keyed table could desync after VACUUM.
        migrator.registerMigration("v2-search-name") { db in
            try db.execute(sql: """
                DROP TRIGGER IF EXISTS channels_ai;
                DROP TRIGGER IF EXISTS channels_ad;
                DROP TRIGGER IF EXISTS channels_au;
                DROP TABLE IF EXISTS channels_fts;
                ALTER TABLE channels ADD COLUMN search_name TEXT NOT NULL DEFAULT '';
                """)
            for row in try Row.fetchAll(db, sql: "SELECT id, name FROM channels") {
                let name: String = row["name"]
                try db.execute(sql: "UPDATE channels SET search_name = ? WHERE id = ?",
                               arguments: [TurkishFold.fold(name), row["id"] as String])
            }
        }
        return migrator
    }

    private static func schemaV1() throws -> String {
        guard let url = Bundle(for: AppDatabase.self).url(forResource: "schema", withExtension: "sql") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "schema.sql is missing from the app bundle"])
        }
        // PRAGMA lines are no-ops inside a migration's transaction; GRDB already enables foreign keys.
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("PRAGMA") }
            .joined(separator: "\n")
    }
}

extension AppDatabase {
    /// The database file in Application Support, protected until first unlock
    /// so background refresh can still open it.
    static let shared: AppDatabase = {
        do {
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true)
            let url = folder.appendingPathComponent("torpido.sqlite")
            let pool = try DatabasePool(path: url.path)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
            return try AppDatabase(pool)
        } catch {
            // A broken database is unrecoverable at launch; surface it loudly in development.
            fatalError("Torpido could not open its database: \(error)")
        }
    }()

    /// An empty in-memory database, for tests and previews.
    static func empty() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }
}

/// Seconds since 1970, UTC: the schema's time format.
enum Clock {
    static func now() -> Int64 { Int64(Date().timeIntervalSince1970) }
}
