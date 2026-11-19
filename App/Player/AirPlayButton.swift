import AVKit
import SwiftUI

/// The system AirPlay picker: lists Apple TVs and AirPlay TVs on the same Wi-Fi
/// and sends the current video there.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = UIColor(Theme.text)
        picker.activeTintColor = UIColor(Theme.accent)
        picker.accessibilityLabel = String(localized: "TV'ye gönder (AirPlay)")
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {}
}
