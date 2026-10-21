import SwiftUI

/// Docked above the tab bar while something plays and the full player is closed.
/// Tapping the bar reopens the player; the trailing button only plays or pauses.
struct MiniPlayerBar: View {
    let title: String
    let subtitle: String?
    let isPlaying: Bool
    let togglePlayback: () -> Void
    let expand: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            Button(action: expand) {
                HStack(spacing: Theme.Space.s12) {
                    ChannelLogo(name: title, url: nil)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        if let subtitle {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundStyle(Theme.textMutedOnSurface)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Oynatıcıyı açar")

            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: Theme.Size.tapMin, height: Theme.Size.tapMin)
            }
            .accessibilityLabel(isPlaying ? "Duraklat" : "Oynat")
        }
        .padding(.horizontal, Theme.Space.s12)
        .frame(minHeight: Theme.Size.miniPlayer)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.perde, style: .continuous))
        .padding(.horizontal, Theme.Space.s8)
    }
}
