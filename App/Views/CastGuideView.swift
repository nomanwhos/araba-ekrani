import SwiftUI
import UIKit

/// How a popular app's video reaches the car through Torpido.
struct CastGuideApp: Identifiable, Hashable {
    enum Route: Hashable {
        /// The app can send to a DLNA receiver; works once Torpido's receiver is on.
        case dlna
        /// No casting to Torpido; mirroring with Perde shows it.
        case mirror
        /// DRM-protected: the picture is black when mirrored, and the app cannot cast to Torpido.
        case protected
    }

    var name: String
    var route: Route
    /// Opens the app if it is installed. Third-party apps' own URL schemes, no logos.
    var appURL: URL?

    var id: String { name }

    static let all: [CastGuideApp] = [
        CastGuideApp(name: "YouTube", route: .mirror, appURL: URL(string: "youtube://")),
        CastGuideApp(name: "Instagram", route: .mirror, appURL: URL(string: "instagram://")),
        CastGuideApp(name: "TikTok", route: .mirror, appURL: URL(string: "snssdk1233://")),
        CastGuideApp(name: "VLC", route: .dlna, appURL: URL(string: "vlc://")),
        CastGuideApp(name: "Plex", route: .dlna, appURL: URL(string: "plex://")),
        CastGuideApp(name: "Infuse", route: .dlna, appURL: URL(string: "infuse://")),
        CastGuideApp(name: "Netflix", route: .protected, appURL: URL(string: "nflx://")),
        CastGuideApp(name: "Prime Video", route: .protected, appURL: URL(string: "aiv://")),
        CastGuideApp(name: "Disney+", route: .protected, appURL: URL(string: "disneyplus://")),
    ]
}

/// S06 / S06b: which apps can reach the car screen, and how.
struct CastGuideView: View {
    @State private var selected: CastGuideApp?

    var body: some View {
        List {
            Section {
                ForEach(CastGuideApp.all) { app in
                    Button {
                        selected = app
                    } label: {
                        HStack(spacing: Theme.Space.s12) {
                            Image(systemName: symbol(for: app.route))
                                .foregroundStyle(.secondary)
                                .frame(width: Theme.Size.tapMin)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).foregroundStyle(Theme.text)
                                Text(summary(for: app.route))
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textMutedOnSurface)
                            }
                        }
                        .frame(minHeight: Theme.Size.tapMin)
                    }
                }
            } footer: {
                Text("Torpido'nun alıcı olarak görünmesi (DLNA) Apple'ın ağ iznini bekliyor. O zamana kadar her uygulama Perde ile yansıtılabilir; korumalı olanlar hariç.")
            }
            .listRowBackground(Theme.surface)
        }
        .nightGround()
        .navigationTitle("Uygulamadan gönder")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { app in
            CastGuideDetail(app: app)
                .presentationDetents([.medium])
        }
    }

    private func symbol(for route: CastGuideApp.Route) -> String {
        switch route {
        case .dlna: "airplayvideo"
        case .mirror: "rectangle.on.rectangle"
        case .protected: "lock.shield"
        }
    }

    private func summary(for route: CastGuideApp.Route) -> String {
        switch route {
        case .dlna: "Kendi Gönder düğmesiyle (DLNA)"
        case .mirror: "Perde ile yansıtın"
        case .protected: "Korumalı: arabada görüntü siyah kalır"
        }
    }
}

private struct CastGuideDetail: View {
    let app: CastGuideApp
    @Environment(\.dismiss) private var dismiss
    @State private var notInstalled = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Space.s16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Label {
                        Text(step)
                    } icon: {
                        Image(systemName: "\(index + 1).circle.fill").foregroundStyle(.secondary)
                    }
                }
                if notInstalled {
                    Text("\(app.name) bu iPhone'da yüklü değil.")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }
                Spacer()
                if let url = app.appURL, app.route != .protected {
                    Button {
                        UIApplication.shared.open(url) { opened in notInstalled = !opened }
                    } label: {
                        Text("\(app.name) uygulamasını aç")
                            .font(.headline)
                            .foregroundStyle(Theme.onAccent)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.tapMin)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(Theme.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bg)
            .navigationTitle(app.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Tamam") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var steps: [String] {
        switch app.route {
        case .mirror:
            ["Önce Perde'de Yansıtmayı Başlat'a dokunun.",
             "\(app.name)'u açın ve videoyu oynatın; telefon ekranı arabada görünür.",
             "Sesi telefondan arabaya her zamanki gibi gelir."]
        case .dlna:
            ["\(app.name)'ta videoyu açın ve Gönder (Cast) düğmesine dokunun.",
             "Listeden Torpido'yu seçin. Bu adım Apple'ın ağ izni geldikten sonra çalışacak.",
             "O zamana kadar Perde ile yansıtabilirsiniz."]
        case .protected:
            ["\(app.name) videolarını kopya korumasıyla (DRM) gönderir.",
             "Ekran yansıtmada görüntü siyah, ses açık kalır; bu, servisin kuralı.",
             "Arabada izlemek için videoyu \(app.name) uygulamasından indirip telefonda izleyin."]
        }
    }
}
