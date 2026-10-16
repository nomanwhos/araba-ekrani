import SwiftUI

struct SettingsView: View {
    @Bindable private var state = MirrorState.shared

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        Toggle("Görüntüyü ekrana doldur", isOn: $state.fillsCarScreen)
                    } header: {
                        Text("Araba ekranı")
                    } footer: {
                        Text("Kapalıyken görüntü kenarlarda siyah boşlukla sığdırılır. Arabada sol üstteki düğmeyle de değiştirebilirsiniz.")
                    }

                    Section("Nasıl çalışır") {
                        Step(number: 1, text: "iPhone'u CarPlay'e bağlayın. Torpido araba ekranında da açılır.")
                        Step(number: 2, text: "Perde sekmesinde Yansıtmayı Başlat'a dokunun ve açılan pencerede Yayını Başlat'ı seçin.")
                        Step(number: 3, text: "İzlemek istediğiniz uygulamaya geçin. Telefon ekranı arabada görünür.")
                    }

                    Section("Bilinmesi gerekenler") {
                        Label("Ses, telefondaki uygulamadan arabaya her zamanki gibi gelir.", systemImage: "speaker.wave.2")
                        Label("Araba ekranında kısa bir gecikme olabilir.", systemImage: "timer")
                        Label("Araba ekranına dokunmak telefonu kontrol etmez.", systemImage: "hand.tap")
                    }

                    Section("Hakkında") {
                        LabeledContent("Sürüm", value: Self.version)
                    }
                }
                .listRowBackground(Color("NightRaised"))
            }
            .nightGround()
            .navigationTitle("Ayarlar")
        }
    }

    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
}

private struct Step: View {
    let number: Int
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "\(number).circle.fill")
                .foregroundStyle(Color.accentColor)
        }
    }
}
