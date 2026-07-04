import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStorage
    @State private var lidSupported = LidAngleMonitor.isSupported()

    var body: some View {
        TabView {
            protectionTab
                .tabItem { Label("Protection", systemImage: "shield") }
            sensorsTab
                .tabItem { Label("Sensors", systemImage: "sensor.tag.radiowaves.forward") }
            alarmTab
                .tabItem { Label("Alarm", systemImage: "speaker.wave.3") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WindowActivator())
        .onDisappear { settings.save() }
    }

    private var protectionTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Auto-arm when I walk away from my MacBook", isOn: $settings.autoArmOnWalkAway)
            Text("When enabled, LurkAway scans for your face periodically. When no face is detected for about 5 seconds, theft protection arms automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    private var sensorsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trigger the alarm while armed when…")
                .font(.headline)

            Toggle("AC power disconnected", isOn: $settings.armWithPower)
                .disabled(isLastEnabled(settings.armWithPower))
            Toggle("Lid moved", isOn: $settings.armWithLid)
                .disabled(!lidSupported || isLastEnabled(settings.armWithLid && lidSupported))
            Toggle("Camera detects motion", isOn: $settings.armWithCamera)
                .disabled(isLastEnabled(settings.armWithCamera))

            if settings.armWithCamera {
                Divider().padding(.vertical, 4)
                Text("Camera sensitivity")
                Slider(value: $settings.motionSensitivity, in: 0...1)
            }

            Text(sensorFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .toggleStyle(.switch)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    private var alarmTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lock screen message")
                .font(.headline)
            TextField("Message shown when the alarm triggers", text: $settings.lockMessage, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...12)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
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

/// Brings the Settings window to the front and activates the (accessory) app when it opens.
private struct WindowActivator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            view.window?.makeKeyAndOrderFront(nil)
            view.window?.orderFrontRegardless()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
