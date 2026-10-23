import Observation
import SwiftUI
import WebKit

/// Keeps one web view alive while the browser is open, and mirrors its state for SwiftUI.
/// Sign-ins stay, because the default website data store is used.
@MainActor
@Observable
final class BrowserModel {
    let webView: WKWebView
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isLoading = false
    private(set) var title = ""
    private(set) var currentURL: URL?
    private var observations: [NSKeyValueObservation] = []

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.canGoBack) { [weak self] view, _ in self?.update(view) },
            webView.observe(\.canGoForward) { [weak self] view, _ in self?.update(view) },
            webView.observe(\.isLoading) { [weak self] view, _ in self?.update(view) },
            webView.observe(\.title) { [weak self] view, _ in self?.update(view) },
            webView.observe(\.url) { [weak self] view, _ in self?.update(view) },
        ]
    }

    func open(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    nonisolated private func update(_ view: WKWebView) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            canGoBack = view.canGoBack
            canGoForward = view.canGoForward
            isLoading = view.isLoading
            title = view.title ?? ""
            currentURL = view.url
        }
    }
}

/// S07: an in-app browser for sites like YouTube, with bookmarks.
struct BrowserView: View {
    @State private var model = BrowserModel()
    @State private var address = ""
    @State private var bookmarks: [Bookmark] = []
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Adres ya da arama", text: $address)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($addressFocused)
                .onSubmit(go)
                .padding(.horizontal, Theme.Space.s12)
                .frame(minHeight: Theme.Size.tapMin)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                .padding(Theme.Space.s12)
                .accessibilityLabel("Adres ya da arama")

            if model.currentURL == nil {
                startPage
            } else {
                WebViewHost(webView: model.webView)
            }
        }
        .background(Theme.bg)
        .navigationTitle(model.title.isEmpty ? "Tarayıcı" : model.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .onChange(of: model.currentURL) { _, url in
            if !addressFocused { address = url?.absoluteString ?? "" }
        }
        .task {
            do {
                for try await value in AppDatabase.shared.observe(LibraryQueries.bookmarks) { bookmarks = value }
            } catch {
                bookmarks = []
            }
        }
    }

    private var startPage: some View {
        List {
            Section {
                ForEach(QuickLink.all) { link in
                    Button(link.name) { model.open(link.url) }
                        .foregroundStyle(Theme.text)
                }
            } header: {
                Text("Hızlı başlangıç")
            } footer: {
                Text("Netflix ve Prime Video iPhone'da tarayıcıda oynatmaz ve korumalı videoları yansıtmada siyah görünür. YouTube ve korumasız siteler çalışır.")
            }
            .listRowBackground(Theme.surface)

            if !bookmarks.isEmpty {
                Section("Yer imleri") {
                    ForEach(bookmarks) { bookmark in
                        Button {
                            if let url = URL(string: bookmark.url) { model.open(url) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bookmark.title).foregroundStyle(Theme.text)
                                Text(bookmark.url).font(.footnote).foregroundStyle(Theme.textMutedOnSurface).lineLimit(1)
                            }
                        }
                        .swipeActions {
                            Button("Sil", role: .destructive) { try? BookmarkStore(database: .shared).remove(bookmark) }
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
        }
        .nightGround()
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button { model.webView.goBack() } label: { Image(systemName: "chevron.backward") }
                .disabled(!model.canGoBack)
                .accessibilityLabel("Geri")
            Button { model.webView.goForward() } label: { Image(systemName: "chevron.forward") }
                .disabled(!model.canGoForward)
                .accessibilityLabel("İleri")
            Spacer()
            Button {
                if model.isLoading {
                    model.webView.stopLoading()
                } else {
                    model.webView.reload()
                }
            } label: {
                Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
            }
            .disabled(model.currentURL == nil)
            .accessibilityLabel(model.isLoading ? "Durdur" : "Yenile")
            Button {
                if let url = model.currentURL { try? BookmarkStore(database: .shared).toggle(url: url, title: model.title) }
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            }
            .disabled(model.currentURL == nil)
            .accessibilityLabel(isBookmarked ? "Yer iminden çıkar" : "Yer imi ekle")
        }
    }

    private var isBookmarked: Bool {
        guard let url = model.currentURL?.absoluteString else { return false }
        return bookmarks.contains { $0.url == url }
    }

    private func go() {
        guard let url = BrowserAddress.url(from: address) else { return }
        model.open(url)
        addressFocused = false
    }
}

private struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
