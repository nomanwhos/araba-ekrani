import SwiftUI

/// The five kinds of source, with the symbol and name used everywhere a source appears.
enum SourceKind: String, CaseIterable, Identifiable {
    case m3u, xtream, jellyfin, emby, plex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .m3u: String(localized: "M3U listesi")
        case .xtream: String(localized: "Xtream hesabı")
        case .jellyfin: String(localized: "Jellyfin")
        case .emby: String(localized: "Emby")
        case .plex: String(localized: "Plex")
        }
    }

    var detail: String {
        switch self {
        case .m3u: String(localized: "Bağlantıyı yapıştırın ya da QR kodunu okutun")
        case .xtream: String(localized: "Sunucu adresi, kullanıcı adı ve şifre")
        case .jellyfin, .emby: String(localized: "Kendi sunucunuzun adresi ve hesabınız")
        case .plex: String(localized: "Plex hesabınızla giriş")
        }
    }

    var symbol: String {
        switch self {
        case .m3u: "list.bullet.rectangle"
        case .xtream: "antenna.radiowaves.left.and.right"
        case .jellyfin, .emby, .plex: "server.rack"
        }
    }
}

/// A row for choosing or showing a source kind.
struct SourceKindLabel: View {
    let kind: SourceKind

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .foregroundStyle(Theme.text)
                Text(kind.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textMutedOnSurface)
            }
        } icon: {
            Image(systemName: kind.symbol)
                .foregroundStyle(Theme.textMutedOnSurface)
        }
        .frame(minHeight: Theme.Size.tapMin)
    }
}
