import SwiftUI

/// Health of a channel's first stream, from the background check.
enum ChannelHealth: Equatable {
    case unknown
    case ok(latencyMs: Int)
    case down
}

/// One channel in a list: logo, name, optional group, health, favourite.
struct ChannelRow: View {
    let name: String
    let logoURL: URL?
    var group: String?
    var health: ChannelHealth = .unknown
    var isFavorite = false
    var isPlaying = false

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            ChannelLogo(name: name, url: logoURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(isPlaying ? .semibold : .regular))
                    .foregroundStyle(isPlaying ? Theme.accent : Theme.text)
                    .lineLimit(2)
                if let group {
                    Text(group)
                        .font(.footnote)
                        .foregroundStyle(Theme.textMutedOnSurface)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Theme.Space.s8)
            HealthBadge(health: health)
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Favori")
            }
        }
        .frame(minHeight: Theme.Size.tapMin)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPlaying ? [.isButton, .isSelected] : .isButton)
    }
}

/// The playlist's tvg-logo, or the channel's initials on a raised tile while
/// it loads or when there is none.
struct ChannelLogo: View {
    let name: String
    let url: URL?
    @ScaledMetric(relativeTo: .body) private var side = Theme.Size.channelLogo

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit().padding(4)
            } else {
                Text(initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textMutedOnSurface)
            }
        }
        .frame(width: side, height: side)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .accessibilityHidden(true)
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased(with: Locale(identifier: "tr_TR"))
    }
}

/// Latency in ms coloured by speed, or a slashed symbol when the stream is down.
struct HealthBadge: View {
    private static let fastMs = 300
    private static let slowMs = 1000

    let health: ChannelHealth

    var body: some View {
        switch health {
        case .unknown:
            EmptyView()
        case .ok(let latencyMs):
            Text("\(latencyMs) ms")
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(color(for: latencyMs))
                .accessibilityLabel("Gecikme \(latencyMs) milisaniye")
        case .down:
            Image(systemName: "wifi.slash")
                .font(.footnote)
                .foregroundStyle(Theme.danger)
                .accessibilityLabel("Yayın şu an kapalı")
        }
    }

    private func color(for latencyMs: Int) -> Color {
        if latencyMs < Self.fastMs { return Theme.success }
        return latencyMs < Self.slowMs ? Theme.warning : Theme.danger
    }
}
