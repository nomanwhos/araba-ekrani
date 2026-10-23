import SwiftUI

/// S09b: add an M3U link, an Xtream account or a Jellyfin server.
struct AddSourceView: View {
    private enum Kind: String, CaseIterable, Identifiable {
        case m3u = "M3U", xtream = "Xtream", jellyfin = "Jellyfin"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var kind = Kind.m3u
    @State private var urlText = ""
    @State private var username = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isAdding = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kaynak türü", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                switch kind {
                case .m3u: m3uFields
                case .xtream, .jellyfin: serverFields
                }

                Section("Ad (isteğe bağlı)") {
                    TextField("Örn. Ev listesi", text: $name)
                        .accessibilityLabel("Kaynağın adı")
                }
                .listRowBackground(Theme.surface)
            }
            .nightGround()
            .navigationTitle("Kaynak ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                    } else {
                        Button("Ekle", action: add).disabled(!canAdd)
                    }
                }
            }
            .interactiveDismissDisabled(isAdding)
            .onChange(of: kind) { error = nil }
        }
        .preferredColorScheme(.dark)
    }

    private var m3uFields: some View {
        Section {
            TextField("https://…/liste.m3u", text: $urlText, axis: .vertical)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Liste bağlantısı")
            PasteButton(payloadType: String.self) { strings in
                if let first = strings.first { urlText = first }
            }
            .labelStyle(.titleAndIcon)
        } header: {
            Text("M3U bağlantısı")
        } footer: {
            footer(hint: "IPTV sağlayıcınızın verdiği .m3u ya da .m3u8 adresi. Torpido kanal içermez; liste sizin. Bağlantıdaki şifre iPhone'un anahtar zincirinde saklanır.")
        }
        .listRowBackground(Theme.surface)
    }

    private var serverFields: some View {
        Section {
            TextField(kind == .xtream ? "http://sunucu.com:8080" : "http://192.168.1.10:8096", text: $urlText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Sunucu adresi")
            TextField("Kullanıcı adı", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
            SecureField("Şifre", text: $password)
                .textContentType(.password)
        } header: {
            Text(LocalizedStringKey(kind == .xtream ? "Xtream hesabı" : "Jellyfin sunucusu"))
        } footer: {
            footer(hint: kind == .xtream
                   ? "Sağlayıcınızın verdiği sunucu adresi, kullanıcı adı ve şifre. Şifre yalnızca bu iPhone'un anahtar zincirinde durur."
                   : "Kendi Jellyfin sunucunuzun adresi ve hesabınız. Filmler ve diziler Ana Sayfa'daki sunucu satırından açılır.")
        }
        .listRowBackground(Theme.surface)
    }

    @ViewBuilder
    private func footer(hint: LocalizedStringKey) -> some View {
        if let error {
            Text(error).foregroundStyle(Theme.danger)
        } else {
            Text(hint)
        }
    }

    private var canAdd: Bool {
        let hasURL = !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch kind {
        case .m3u: return hasURL
        case .xtream: return hasURL && !username.isEmpty && !password.isEmpty
        case .jellyfin: return hasURL && !username.isEmpty
        }
    }

    private func add() {
        error = nil
        isAdding = true
        let service = SourceService(database: .shared)
        Task {
            do {
                switch kind {
                case .m3u:
                    _ = try await service.addM3U(urlText: urlText, name: name)
                case .xtream:
                    _ = try await service.addXtream(serverText: urlText, username: username, password: password, name: name)
                case .jellyfin:
                    _ = try await service.addJellyfin(serverText: urlText, username: username, password: password, name: name)
                }
                dismiss()
            } catch {
                self.error = error.localizedDescription
                AccessibilityNotification.Announcement(error.localizedDescription).post()
            }
            isAdding = false
        }
    }
}
