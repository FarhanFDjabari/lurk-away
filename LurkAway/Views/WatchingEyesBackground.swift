import SwiftUI
import Combine

/// Faint, slowly-glancing pair of eyes rendered behind the lock message.
/// Purely decorative — never intercepts touches.
struct WatchingEyesBackground: View {
    @State private var gaze: CGSize = .zero
    @State private var blink = false

    private let gazeTimer = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()
    private let blinkTimer = Timer.publish(every: 5.7, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let eyeWidth = min(geo.size.width * 0.15, 220)
            let eyeHeight = eyeWidth * 1.45
            let spacing = eyeWidth * 0.55

            HStack(spacing: spacing) {
                eye(width: eyeWidth, height: eyeHeight)
                eye(width: eyeWidth, height: eyeHeight)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.4)
        }
        .opacity(0.08)
        .allowsHitTesting(false)
        .onReceive(gazeTimer) { _ in
            withAnimation(.easeInOut(duration: 1.3)) {
                gaze = CGSize(width: .random(in: -1...1), height: .random(in: -0.5...1))
            }
        }
        .onReceive(blinkTimer) { _ in
            withAnimation(.easeIn(duration: 0.09)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.12)) { blink = false }
            }
        }
    }

    private func eye(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(.white)
                .frame(width: width, height: height)

            Circle()
                .fill(.black)
                .frame(width: width * 0.52, height: width * 0.52)
                .offset(x: gaze.width * width * 0.2, y: gaze.height * height * 0.22)
        }
        .scaleEffect(x: 1, y: blink ? 0.08 : 1, anchor: .center)
    }
}
