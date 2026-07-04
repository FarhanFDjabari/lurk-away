import SwiftUI

/// Full-screen armed overlay content, shown on top of the blurred live screen: the faint
/// watching eyes, the top "watching" capsule, and an Unlock button. The system Touch ID
/// dialog only appears when the owner presses Unlock.
struct ArmedOverlayView: View {
    let onDisarm: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            WatchingEyesBackground()
                .ignoresSafeArea()

            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                    Text("LurkAway is watching — look away, it's got this")
                        .fontWeight(.medium)
                }
                .font(.callout)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
                .opacity(pulse ? 0.9 : 0.55)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 44)

            VStack(spacing: 18) {
                Spacer()

                Button(action: onDisarm) {
                    HStack(spacing: 14) {
                        Image(systemName: "touchid")
                            .font(.system(size: 30, weight: .semibold))
                        Text("Unlock")
                            .font(.system(size: 26, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 24)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
                }
                .buttonStyle(.plain)

                Text("Use Touch ID or your device password")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
