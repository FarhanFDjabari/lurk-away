import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStorage
    @State private var lidSupported = LidAngleMonitor.isSupported()

    var body: some View {
        TabView {
            protectionTab
                .tabItem { Label("Protection", systemImage: "shield") }
                .padding()

            sensorsTab
                .tabItem { Label("Sensors", systemImage: "sensor.tag.radiowaves.forward") }
                .padding()

            alarmTab
                .tabItem { Label("Alarm", systemImage: "speaker.wave.3") }
                .padding()
        }
        .onDisappear { settings.save() }
    }

    private var protectionTab: some View {
        Form {
            Toggle("Auto-arm when I walk away from my MacBook", isOn: $settings.autoArmOnWalkAway)
            Text("When enabled, LurkAway scans for your face periodically. When no face is detected for about 5 seconds, theft protection arms automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sensorsTab: some View {
        Form {
            Section {
                Toggle("AC power disconnected", isOn: $settings.armWithPower)
                    .disabled(isLastEnabled(settings.armWithPower))
                Toggle("Lid moved", isOn: $settings.armWithLid)
                    .disabled(!lidSupported || isLastEnabled(settings.armWithLid && lidSupported))
                Toggle("Camera detects motion", isOn: $settings.armWithCamera)
                    .disabled(isLastEnabled(settings.armWithCamera))
            } header: {
                Text("Trigger the alarm while armed when…")
            } footer: {
                Text(sensorFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.armWithCamera {
                HStack {
                    Text("Camera sensitivity")
                    Slider(value: $settings.motionSensitivity, in: 0...1)
                }
            }
        }
    }

    private var alarmTab: some View {
        Form {
            VStack(alignment: .leading) {
                Text("Lock screen message")
                TextField("Lock screen message", text: $settings.lockMessage, axis: .vertical)
                    .lineLimit(5...10)
            }
        }
    }

    /// Number of sensors that would actually run while armed.
    private var enabledSensorCount: Int {
        var count = 0
        if settings.armWithPower { count += 1 }
        if settings.armWithLid && lidSupported { count += 1 }
        if settings.armWithCamera { count += 1 }
        return count
    }

    /// A sensor can't be switched off when it's the only one keeping protection functional.
    private func isLastEnabled(_ isThisOn: Bool) -> Bool {
        isThisOn && enabledSensorCount == 1
    }

    private var sensorFooter: String {
        var lines = ["At least one sensor must stay on. Power and lid are near-zero cost; camera uses more battery."]
        if !lidSupported {
            lines.append("The lid sensor isn't available on this Mac.")
        }
        return lines.joined(separator: " ")
    }
}
