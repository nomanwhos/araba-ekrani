import ReplayKit
import SwiftUI

/// iOS only lets the system broadcast sheet start a screen broadcast, and only
/// from its own RPSystemBroadcastPickerView. We keep that view hidden and
/// forward taps from Torpido's own button to it.
@MainActor
final class BroadcastPicker {
    let view: RPSystemBroadcastPickerView = {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = Bundle.main.bundleIdentifier.map { "\($0).broadcast" }
        picker.showsMicrophoneButton = false
        return picker
    }()

    func present() {
        view.subviews
            .compactMap { $0 as? UIButton }
            .first?
            .sendActions(for: .touchUpInside)
    }
}

struct BroadcastPickerHost: UIViewRepresentable {
    let picker: BroadcastPicker

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        picker.view
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
