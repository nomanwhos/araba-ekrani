import AVFoundation
import Foundation
import GRDB

enum LocalVideoError: LocalizedError, Equatable {
    case notEnoughSpace(neededMB: Int)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notEnoughSpace(let needed): "Telefonda yer yok: bu video için yaklaşık \(needed) MB gerekiyor."
        case .unreadable: "Video okunamadı. Dosya bozuk olabilir ya da iCloud'dan henüz inmemiş olabilir."
        }
    }
}

/// Videos copied into the app so they play offline (S19): import, list, rename, delete.
/// Files live in Application Support/Videos; the database keeps the names and order.
struct LocalVideoStore {
    /// Free space left on the phone after a copy, so an import never fills the disk.
    private static let reserveBytes: Int64 = 500 * 1024 * 1024

    let database: AppDatabase
    var folder: URL = LocalVideoStore.defaultFolder

    static var defaultFolder: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Videos", isDirectory: true)
    }

    func fileURL(for video: LocalVideo) -> URL {
        folder.appendingPathComponent(video.fileName)
    }

    /// Copies a picked file into the app. `source` may be security-scoped (Files app).
    func importVideo(from source: URL, suggestedName: String? = nil) async throws -> LocalVideo {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        guard let size = (try? source.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) else {
            throw LocalVideoError.unreadable
        }
        try checkFreeSpace(for: size)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileExtension = source.pathExtension.isEmpty ? "mov" : source.pathExtension.lowercased()
        let fileName = UUID().uuidString + "." + fileExtension
        let destination = folder.appendingPathComponent(fileName)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            throw LocalVideoError.unreadable
        }
        let duration = try? await AVURLAsset(url: destination).load(.duration).seconds
        let name = suggestedName ?? source.deletingPathExtension().lastPathComponent
        do {
            return try await database.writer.write { db in
                let next = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sort_order) + 1, 0) FROM local_videos") ?? 0
                let video = LocalVideo(id: UUID().uuidString, fileName: fileName,
                                       displayName: name.isEmpty ? "Video" : name, folder: "", sortOrder: next,
                                       byteSize: size, durationS: duration.flatMap { $0.isFinite ? $0 : nil },
                                       importedAt: Clock.now())
                try video.insert(db)
                return video
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    func rename(_ video: LocalVideo, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try database.writer.write { db in
            try db.execute(sql: "UPDATE local_videos SET display_name = ? WHERE id = ?", arguments: [trimmed, video.id])
        }
    }

    /// Removes the row, its favourite and resume position, then the file.
    func delete(_ video: LocalVideo) throws {
        try database.writer.write { db in
            _ = try video.delete(db)
            try OrphanCleanup.run(db)
        }
        try? FileManager.default.removeItem(at: fileURL(for: video))
    }

    private func checkFreeSpace(for size: Int64) throws {
        let values = try? folder.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let free = values?.volumeAvailableCapacityForImportantUsage else { return }
        if free - size < Self.reserveBytes {
            throw LocalVideoError.notEnoughSpace(neededMB: Int((size + Self.reserveBytes - free) / 1_048_576) + 1)
        }
    }
}

extension LibraryQueries {
    static func localVideos(_ db: Database) throws -> [LocalVideo] {
        try LocalVideo.order(Column("sort_order")).fetchAll(db)
    }
}
