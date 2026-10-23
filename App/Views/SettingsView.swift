import SwiftUI

struct SettingsView: View {
    @Bindable private var state = MirrorState.shared

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        NavigationLink {
                            SourcesView()
                        } label: {
                            Label {
                                Text("Kaynaklar")
                            } icon: {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Kanallar")
                    } footer: {
                        Text("M3U listelerinizi ekleyin, yenileyin ya da silin.")
                    }

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
                        Note(text: "Ses, telefondaki uygulamadan arabaya her zamanki gibi gelir.", symbol: "speaker.wave.2")
                        Note(text: "Araba ekranında kısa bir gecikme olabilir.", symbol: "timer")
                        Note(text: "Araba ekranına dokunmak telefonu kontrol etmez.", symbol: "hand.tap")
                        Note(text: "Netflix, Prime Video gibi korumalı videolar yansıtmada siyah görünür; bu, o servislerin koruması.", symbol: "lock.shield")
                    }

                    Section("Hakkında") {
                        LabeledContent("Sürüm", value: Self.version)
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .nightGround()
            .navigationTitle("Ayarlar")
            .miniPlayerInset()
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
                .foregroundStyle(.secondary)
        }
    }
}

private struct Note: View {
    let text: String
    let symbol: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
        }
    }
}
