import SwiftUI

/// Faint, non-interactive "watching" indicator shown while armed. Fixed wording (not
/// customizable), light enough that the screen stays usable behind it.
struct ArmedIndicatorView: View {
    @State private var pulse = false

    var body: some View {
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
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
