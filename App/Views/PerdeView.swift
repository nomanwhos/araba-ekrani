import SwiftUI

/// The cast tab: the screen, the one action, and the live status.
struct PerdeView: View {
    private let state = MirrorState.shared
    @State private var picker = BroadcastPicker()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MarqueeScreen(stage: stage, framesPerSecond: state.framesPerSecond)
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
                    if let error = state.serverError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Durum")
                } footer: {
                    Text("Sadece yolcuyken ya da araç park halindeyken kullanın. Araç kullanırken izlemeyin.")
                }
                .listRowBackground(Color("NightRaised"))
            }
            .nightGround()
            .navigationTitle("Torpido")
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
                .font(.headline)
                .foregroundStyle(Color("Night"))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
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
            Label(title, systemImage: symbol)
        }
    }
}
