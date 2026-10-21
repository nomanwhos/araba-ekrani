import SwiftUI

/// What a list shows before it has anything: a symbol, one line that names
/// what is missing, one line on how to fix it, and at most one action.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Space.s12) {
            Image(systemName: symbol)
                .font(.system(.largeTitle))
                .foregroundStyle(Theme.textMuted)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.top, Theme.Space.s4)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 320)
        .padding(Theme.Space.s24)
        .frame(maxWidth: .infinity)
    }
}
