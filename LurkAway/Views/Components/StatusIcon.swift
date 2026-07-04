import SwiftUI

struct StatusIcon: View {
    let isArmed: Bool
    let isAlarming: Bool

    var body: some View {
        Image("StatusGlyph")
            .renderingMode(.template)
            .foregroundStyle(color)
    }

    private var color: Color {
        if isAlarming { return .red }
        return isArmed ? .orange : .green
    }
}
