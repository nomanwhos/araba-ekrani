import SwiftUI

/// The cast tab: the screen, the one action, and the live status.
struct PerdeView: View {
    private let state = MirrorState.shared
    @State private var picker = BroadcastPicker()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MarqueeScreen(stage: stage)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 20, trailing: 0))
                    startButton
                        .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    StatusRow(title: "CarPlay", symbol: "car.fill",
                              value: state.isCarConnected ? "Bağlı" : "Bağlı değil",
                              isOn: state.isCarConnected)
                    StatusRow(title: "Yayın", symbol: "dot.radiowaves.left.and.right",
                              value: state.isStreaming ? "Açık" : "Kapalı",
                              isOn: state.isStreaming)
                    if state.isStreaming && state.framesPerSecond > 0 {
                        StatusRow(title: "Kare hızı", symbol: "speedometer",
                                  value: "\(state.framesPerSecond) kare/sn", isOn: true)
                    }
                    if let error = state.serverError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Durum")
                } footer: {
                    Text("Sadece yolcuyken ya da araç park halindeyken kullanın. Araç kullanırken izlemeyin.")
                }
                .listRowBackground(Theme.surface)

                Section {
                    NavigationLink {
                        BrowserView()
                    } label: {
                        Label {
                            Text("Tarayıcı")
                        } icon: {
                            Image(systemName: "safari").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("YouTube gibi siteleri Torpido'da açın; perdeyle arabaya yansıtın.")
                }
                .listRowBackground(Theme.surface)
            }
            .nightGround()
            .navigationTitle("Torpido")
            .miniPlayerInset()
            // The marquee carries the name; the bar's title stays for accessibility only.
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var stage: MarqueeScreen.Stage {
        if state.isStreaming { return .live }
        return state.isCarConnected ? .ready : .waitingForCar
    }

    private var startButton: some View {
        Button {
            picker.present()
        } label: {
            Label(state.isStreaming ? "Yansıtmayı Durdur" : "Yansıtmayı Başlat",
                  systemImage: state.isStreaming ? "stop.fill" : "play.fill")
                // At accessibility sizes the icon goes so the words wrap whole instead of hyphenating.
                .labelStyle(dynamicTypeSize.isAccessibilitySize ? AnyLabelStyle(TitleOnlyLabelStyle()) : AnyLabelStyle(TitleAndIconLabelStyle()))
                .font(.headline)
                .foregroundStyle(Theme.bg)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .background(BroadcastPickerHost(picker: picker).frame(width: 1, height: 1).opacity(0))
    }
}

private struct StatusRow: View {
    let title: String
    let symbol: String
    let value: String
    let isOn: Bool

    var body: some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
            }
        }
    }
}

/// Type-erases the two label styles the start button switches between.
private struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView

    init<S: LabelStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
