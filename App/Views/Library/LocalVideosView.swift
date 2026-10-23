import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// S19: videos copied into the app. Import from Files or Photos, play offline,
/// rename, delete.
struct LocalVideosView: View {
    @State private var videos: [LocalVideo]?
    @State private var importingFile = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var message: String?
    @State private var renaming: LocalVideo?
    @State private var newName = ""
    private let player = PlayerController.shared
    private var store: LocalVideoStore { LocalVideoStore(database: .shared) }

    var body: some View {
        Group {
            switch videos {
            case nil:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let videos? where videos.isEmpty && !isImporting:
                VStack(spacing: Theme.Space.s12) {
                    EmptyState(symbol: "film", title: "Video yok",
                               message: "Dosyalar'dan ya da Fotoğraflar'dan video ekleyin; internet olmadan da oynar.")
                    importButtons
                    messageText
                }
                .frame(maxHeight: .infinity)
            case let videos?:
                List {
                    Section {
                        ForEach(videos) { video in
                            Button {
                                player.play(video)
                            } label: {
                                LocalVideoRow(video: video, isPlaying: player.nowPlaying?.localVideoID == video.id)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Sil", role: .destructive) { delete(video) }
                                Button("Adlandır") {
                                    newName = video.displayName
                                    renaming = video
                                }
                                .tint(Theme.accent)
                            }
                        }
                        if isImporting {
                            Label("Video kopyalanıyor…", systemImage: "arrow.down.doc")
                                .foregroundStyle(Theme.textMutedOnSurface)
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: Theme.Space.s8) {
                            importButtons
                            messageText
                        }
                        .padding(.top, Theme.Space.s8)
                    }
                    .listRowBackground(Theme.surface)
                }
                .nightGround()
            }
        }
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): importFiles(urls)
            case .failure(let error): message = error.localizedDescription
            }
        }
        .onChange(of: photoItem) { _, item in
            if let item { importPhoto(item) }
        }
        .alert("Videoyu adlandır", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Ad", text: $newName)
            Button("Kaydet") {
                if let renaming { try? store.rename(renaming, to: newName) }
                renaming = nil
            }
            Button("Vazgeç", role: .cancel) { renaming = nil }
        }
        .task {
            do {
                for try await value in AppDatabase.shared.observe(LibraryQueries.localVideos) { videos = value }
            } catch {
                videos = []
            }
        }
    }

    private var importButtons: some View {
        HStack(spacing: Theme.Space.s12) {
            Button {
                importingFile = true
            } label: {
                Label("Dosyalar", systemImage: "folder")
            }
            PhotosPicker(selection: $photoItem, matching: .videos) {
                Label("Fotoğraflar", systemImage: "photo.on.rectangle")
            }
        }
        .buttonStyle(.bordered)
        .disabled(isImporting)
    }

    @ViewBuilder
    private var messageText: some View {
        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.danger)
        }
    }

    private func importFiles(_ urls: [URL]) {
        message = nil
        isImporting = true
        Task {
            for url in urls {
                do {
                    _ = try await store.importVideo(from: url)
                } catch {
                    message = error.localizedDescription
                }
            }
            isImporting = false
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        message = nil
        isImporting = true
        Task {
            defer {
                isImporting = false
                photoItem = nil
            }
            do {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                    message = LocalVideoError.unreadable.localizedDescription
                    return
                }
                defer { try? FileManager.default.removeItem(at: movie.url) }
                _ = try await store.importVideo(from: movie.url, suggestedName: "Fotoğraflar videosu")
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func delete(_ video: LocalVideo) {
        if player.nowPlaying?.localVideoID == video.id { player.stop() }
        do {
            try store.delete(video)
        } catch {
            message = error.localizedDescription
        }
    }
}

/// A video handed over by the Photos picker, copied to a temporary file first.
private struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

private struct LocalVideoRow: View {
    let video: LocalVideo
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            Image(systemName: "film")
                .font(.title3)
                .foregroundStyle(Theme.textMutedOnSurface)
                .frame(width: Theme.Size.channelLogo)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(video.displayName)
                    .foregroundStyle(isPlaying ? Theme.accent : Theme.text)
                    .lineLimit(2)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textMutedOnSurface)
            }
        }
        .frame(minHeight: Theme.Size.tapMin)
        .accessibilityElement(children: .combine)
    }

    /// "1 sa 32 dk · 1,2 GB"
    private var detail: String {
        var parts: [String] = []
        if let seconds = video.durationS {
            parts.append(Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
        }
        parts.append(ByteCountFormatter.string(fromByteCount: video.byteSize, countStyle: .file))
        return parts.joined(separator: " · ")
    }
}
