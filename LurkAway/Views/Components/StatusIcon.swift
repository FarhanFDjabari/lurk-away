import SwiftUI

struct StatusIcon: View {
    let isArmed: Bool
    let isAlarming: Bool

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(color, .white)
    }

    private var iconName: String {
        if isAlarming { return "shield.slash.fill" }
        return isArmed ? "checkmark.shield.fill" : "shield.fill"
    }

    private var color: Color {
        if isAlarming { return .red }
        return isArmed ? .orange : .green
    }
}
