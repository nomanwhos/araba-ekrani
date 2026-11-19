import UIKit

/// Channel names as the car screen shows them.
enum CarPlayText {
    private static let qualityTags = #"\s*(\(\d{3,4}p\)|\[[^\]]*\])"#

    /// Drops playlist tags such as (1080p) and [Not 24/7] from the end of a channel name.
    static func cleanName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: qualityTags, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? name : cleaned
    }
}

/// Channel logos for CarPlay rows: downloaded once, shrunk to the car's size, kept in memory.
@MainActor
final class LogoCache {
    static let shared = LogoCache()
    static let placeholder = UIImage(systemName: "tv")?.withTintColor(.white, renderingMode: .alwaysOriginal) ?? UIImage()

    private let cache = NSCache<NSURL, UIImage>()
    private var waiting: [URL: [(UIImage) -> Void]] = [:]

    /// Calls `completion` with the logo when it is available; never for a missing or broken logo.
    func image(for url: URL?, size: CGSize, completion: @escaping (UIImage) -> Void) {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        if waiting[url] != nil {
            waiting[url]?.append(completion)
            return
        }
        waiting[url] = [completion]
        Task {
            let image = await Self.download(url, fitting: size)
            let callbacks = waiting.removeValue(forKey: url) ?? []
            guard let image else { return }
            cache.setObject(image, forKey: url as NSURL)
            callbacks.forEach { $0(image) }
        }
    }

    private nonisolated static func download(_ url: URL, fitting size: CGSize) async -> UIImage? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              ((response as? HTTPURLResponse)?.statusCode ?? 200) < 400,
              let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(size.width / image.size.width, size.height / image.size.height, 1)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return image.preparingThumbnail(of: target) ?? image
    }
}
