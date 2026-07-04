import SwiftUI
import Combine

/// Faint pair of round eyes (👀) that actively glance around behind the lock message.
/// Purely decorative — never intercepts input.
struct WatchingEyesBackground: View {
    @State private var gaze: CGSize = .zero
    @State private var blink = false

    private let gazeTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    private let blinkTimer = Timer.publish(every: 4.3, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let eyeSize = min(geo.size.width * 0.17, 240)
            let spacing = eyeSize * 0.35

            HStack(spacing: spacing) {
                eye(size: eyeSize)
                eye(size: eyeSize)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
        }
        .opacity(0.13)
        .allowsHitTesting(false)
        .onReceive(gazeTimer) { _ in
            withAnimation(.easeInOut(duration: 0.9)) {
                gaze = CGSize(width: .random(in: -1...1), height: .random(in: -1...1))
            }
        }
        .onReceive(blinkTimer) { _ in
            withAnimation(.easeIn(duration: 0.08)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.13)) { blink = false }
            }
        }
    }

    private func eye(size: CGFloat) -> some View {
        // Round white eye (slightly taller than wide, like 👀) with a large dark pupil.
        let width = size
        let height = size * 1.12
        let pupil = size * 0.42
        let travel = (width - pupil) / 2 * 0.7

        return ZStack {
            Ellipse()
                .fill(.white)
                .frame(width: width, height: height)

            Circle()
                .fill(.black)
                .frame(width: pupil, height: pupil)
                .offset(x: gaze.width * travel, y: gaze.height * travel)
        }
        .scaleEffect(x: 1, y: blink ? 0.1 : 1, anchor: .center)
    }
}
