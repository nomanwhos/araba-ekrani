import SwiftUI

/// The drive-in screen with its bulb row. The bulbs carry the state:
/// off while waiting for the car, steady when ready, chasing while live.
struct MarqueeScreen: View {
    enum Stage {
        case waitingForCar, ready, live
    }

    let stage: Stage
    let framesPerSecond: Int

    var body: some View {
        VStack(spacing: 12) {
            BulbRow(stage: stage)
            screen
        }
        .accessibilityElement(children: .combine)
    }

    /// 16:9 at default text sizes; grows taller instead of truncating at large ones.
    private var screen: some View {
        let isLive = stage == .live
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return caption
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: Self.screenMinHeight)
            .background {
                shape.fill(isLive ? AnyShapeStyle(Self.projectorLight) : AnyShapeStyle(Color.black.opacity(0.4)))
            }
            .overlay {
                shape.strokeBorder(Color.white.opacity(isLive ? 0 : 0.1), lineWidth: 1)
            }
            .animation(.easeOut(duration: 0.4), value: isLive)
    }

    /// 16:9 of the narrowest current iPhone content width (~353pt).
    private static let screenMinHeight: CGFloat = 198

    private var caption: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title)
            Text(title)
                .font(.title3.weight(.bold))
            Text(detail)
                .font(.subheadline)
                .opacity(0.8)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(stage == .live ? Color("Night") : .white)
    }

    private var symbol: String {
        switch stage {
        case .waitingForCar: "car"
        case .ready: "play.rectangle"
        case .live: "dot.radiowaves.left.and.right"
        }
    }

    private var title: String {
        switch stage {
        case .waitingForCar: "Arabaya bağlı değil"
        case .ready: "Perde hazır"
        case .live: "Yayında · \(framesPerSecond) kare/sn"
        }
    }

    private var detail: String {
        switch stage {
        case .waitingForCar: "iPhone'u CarPlay'e bağlayın. Torpido araba ekranında da açılır."
        case .ready: "Aşağıdaki düğmeye dokunun, açılan pencerede Yayını Başlat'ı seçin."
        case .live: "İzlemek istediğiniz uygulamaya geçin."
        }
    }

    /// A projector beam landing on the screen: brightest at the center.
    private static let projectorLight = RadialGradient(
        colors: [Color(red: 0.97, green: 0.96, blue: 0.93), Color(red: 0.80, green: 0.79, blue: 0.76)],
        center: .center, startRadius: 10, endRadius: 260
    )
}

private struct BulbRow: View {
    private static let count = 11
    private static let chaseStep = 0.14

    let stage: MarqueeScreen.Stage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if stage == .live && !reduceMotion {
            TimelineView(.periodic(from: .now, by: Self.chaseStep)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate / Self.chaseStep)
                bulbs { index in (tick + index) % 3 == 0 ? 1 : 0.35 }
            }
        } else {
            bulbs { _ in stage == .waitingForCar ? 0.22 : 1 }
        }
    }

    private func bulbs(brightness: @escaping (Int) -> Double) -> some View {
        HStack {
            ForEach(0..<Self.count, id: \.self) { index in
                let level = brightness(index)
                Circle()
                    .fill(Color.accentColor.opacity(level))
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.accentColor.opacity(level > 0.5 ? 0.9 : 0), radius: 4, x: 0, y: 1)
                if index < Self.count - 1 { Spacer(minLength: 0) }
            }
        }
        .padding(.horizontal, 6)
        .accessibilityHidden(true)
    }
}
