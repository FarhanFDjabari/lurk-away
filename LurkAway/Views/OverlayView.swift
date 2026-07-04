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

                Text("🔒 MacBook Locked")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)

                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "touchid")
                        Text("Unlock with Touch ID")
                    }
                    .font(.title2)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
