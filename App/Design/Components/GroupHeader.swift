import SwiftUI

/// Title of a playlist group on Home, with a way into the full group list.
/// The whole header is the control, so it meets the 44pt target.
struct GroupHeader: View {
    let title: String
    let count: Int
    let showAll: () -> Void

    var body: some View {
        Button(action: showAll) {
            HStack(spacing: Theme.Space.s6) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.textMuted)
                Spacer(minLength: Theme.Space.s8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(minHeight: Theme.Size.tapMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) kanal")
        .accessibilityHint("Gruptaki tüm kanalları gösterir")
    }
}
