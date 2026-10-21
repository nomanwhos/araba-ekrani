import SwiftUI

/// S09b, M3U only for now: paste a playlist link, optionally name it, add.
struct AddSourceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var name = ""
    @State private var isAdding = false
    @State private var error: String?
    @FocusState private var urlFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://…/liste.m3u", text: $urlText, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($urlFocused)
                        .accessibilityLabel("Liste bağlantısı")
                    PasteButton(payloadType: String.self) { strings in
                        if let first = strings.first { urlText = first }
                    }
                    .labelStyle(.titleAndIcon)
                } header: {
                    Text("M3U bağlantısı")
                } footer: {
                    if let error {
                        Text(error).foregroundStyle(Theme.danger)
                    } else {
                        Text("IPTV sağlayıcınızın verdiği .m3u ya da .m3u8 adresi. Torpido kanal içermez; liste sizin.")
                    }
                }
                .listRowBackground(Theme.surface)

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
                        Button("Ekle", action: add)
                            .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(isAdding)
            .onAppear { urlFocused = true }
        }
        .preferredColorScheme(.dark)
    }

    private func add() {
        error = nil
        isAdding = true
        Task {
            do {
                _ = try await SourceService(database: .shared).addM3U(urlText: urlText, name: name)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                AccessibilityNotification.Announcement(error.localizedDescription).post()
            }
            isAdding = false
        }
    }
}
