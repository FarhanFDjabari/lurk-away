import SwiftUI

struct OverlayView: View {
    let message: String
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WatchingEyesBackground()
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.red)

                Text("Device Locked")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)

                Button(action: onUnlock) {
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
        }
    }
}
