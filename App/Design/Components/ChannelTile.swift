import SwiftUI

/// A channel in a Home row: logo on a tile, name below, health in the corner.
struct ChannelTile: View {
    let channel: Channel
    var isFavorite = false
    var isPlaying = false

    @ScaledMetric(relativeTo: .footnote) private var side: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s6) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: channel.logoURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(Theme.Space.s12)
                    } else {
                        Text(Self.initials(channel.name))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textMutedOnSurface)
                    }
                }
                .frame(width: side, height: side)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: isPlaying ? 2 : 0)
                }

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .padding(Theme.Space.s6)
                }
            }
            Text(channel.name)
                .font(.footnote)
                .foregroundStyle(Theme.text)
                .lineLimit(2, reservesSpace: true)
                .frame(width: side, alignment: .leading)
            HealthBadge(health: channel.displayHealth)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private static func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
            .uppercased(with: Locale(identifier: "tr_TR"))
    }
}
