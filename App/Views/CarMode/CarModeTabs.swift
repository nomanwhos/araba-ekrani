import SwiftUI

/// A large channel tile for Car mode: logo, clean name, a ring while it plays.
struct CarTile: View {
    let channel: Channel
    var isFavorite = false

    static let side: CGFloat = 132
    private let player = PlayerController.shared

    var body: some View {
        Button {
            player.play(channel)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.s8) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: channel.logoURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit().padding(Theme.Space.s16)
                        } else {
                            Image(systemName: "tv")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.textMutedOnSurface)
                        }
                    }
                    .frame(width: Self.side, height: Self.side)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.perde, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.perde, style: .continuous)
                            .strokeBorder(Theme.accent, lineWidth: isPlaying ? 3 : 0)
                    }
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.accent)
                            .padding(Theme.Space.s8)
                    }
                }
                .accessibilityHidden(true)
                Text(CarPlayText.cleanName(channel.name))
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .frame(width: Self.side, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CarPlayText.cleanName(channel.name))
        .accessibilityValue(isFavorite ? "Favori" : "")
    }

    private var isPlaying: Bool { player.nowPlaying?.channel?.id == channel.id }
}

/// Every group as a row of large tiles.
struct CarHomeTab: View {
    let favorites: Set<String>
    @State private var sections: [HomeSection] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded && sections.isEmpty {
                EmptyState(symbol: "tv", title: "Henüz kanal yok",
                           message: "Telefonda Ayarlar › Kaynaklar'dan bir liste ekleyin.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.s24) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: Theme.Space.s12) {
                                Text(section.group.title)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Theme.text)
                                    .padding(.horizontal, Theme.Space.s20)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(alignment: .top, spacing: Theme.Space.s16) {
                                        ForEach(section.channels) { channel in
                                            CarTile(channel: channel, isFavorite: favorites.contains(channel.itemKey))
                                        }
                                    }
                                    .padding(.horizontal, Theme.Space.s20)
                                }
                            }
                        }
                    }
                    .padding(.vertical, Theme.Space.s16)
                }
            }
        }
        .task {
            do {
                for try await value in AppDatabase.shared.observe(LibraryQueries.homeSections) {
                    sections = value
                    loaded = true
                }
            } catch {
                loaded = true
            }
        }
    }
}

/// Favourite channels as a grid of large tiles.
struct CarFavoritesTab: View {
    @State private var channels: [Channel] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded && channels.isEmpty {
                EmptyState(symbol: "star", title: "Favori kanal yok",
                           message: "Bir kanalın yıldızına dokunun; burada büyük gösterilir.")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: CarTile.side), spacing: Theme.Space.s20)],
                              alignment: .leading, spacing: Theme.Space.s20) {
                        ForEach(channels) { CarTile(channel: $0, isFavorite: true) }
                    }
                    .padding(Theme.Space.s20)
                }
            }
        }
        .task {
            do {
                for try await value in AppDatabase.shared.observe(LibraryQueries.favoriteChannels) {
                    channels = value
                    loaded = true
                }
            } catch {
                loaded = true
            }
        }
    }
}

/// The DLNA receiver: on/off, how it appears, and what arrived.
struct CarCastTab: View {
    private let receiver = DLNARenderer.shared

    var body: some View {
        VStack(spacing: Theme.Space.s20) {
            Image(systemName: receiver.isOn ? "airplayvideo.circle.fill" : "airplayvideo")
                .font(.system(size: 56))
                .foregroundStyle(receiver.isOn ? Theme.accent : Theme.textMutedOnSurface)
                .accessibilityHidden(true)
            Text("Bu ekrana gönderin")
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.text)
            Text("Alıcı açıkken aynı Wi-Fi'deki uygulamaların ve bilgisayarların Gönder listesinde “Torpido (iPhone)” görünür. Gelen video burada tam ekran açılır.")
                .font(.body)
                .foregroundStyle(Theme.textMutedOnSurface)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
            Toggle(isOn: Binding(get: { receiver.isOn }, set: { receiver.setEnabled($0) })) {
                Text("Alıcı").font(.headline)
            }
            .toggleStyle(.switch)
            .tint(Theme.accent)
            .padding(.horizontal, Theme.Space.s20)
            .frame(maxWidth: 320, minHeight: Theme.Size.tapMin)
            .background(Theme.surface, in: Capsule())
            if let problem = receiver.problem {
                Text(problem).font(.footnote).foregroundStyle(Theme.danger)
            } else if receiver.isOn, let title = receiver.castTitle {
                Label(CarPlayText.cleanName(title), systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(Theme.Space.s24)
    }
}
