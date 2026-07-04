import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStorage
    @EnvironmentObject var appState: AppState
    @StateObject private var launchAtLogin = LaunchAtLogin()
    @State private var lidSupported = LidAngleMonitor.isSupported()
    @State private var daemonStatus: SleepDaemonClient.Status = .notRegistered

    var body: some View {
        TabView {
            protectionTab
                .tabItem { Label("Protection", systemImage: "shield") }
            sensorsTab
                .tabItem { Label("Sensors", systemImage: "sensor.tag.radiowaves.forward") }
            alarmTab
                .tabItem { Label("Alarm", systemImage: "speaker.wave.3") }
            advancedTab
                .tabItem { Label("Advanced", systemImage: "gearshape.2") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WindowActivator())
        .onDisappear { settings.save() }
    }

    private var protectionTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Watch automatically when I walk away", isOn: $settings.autoArmOnWalkAway)
            Text("When enabled, LurkAway watches for your face. When you look away and no face is seen for about 5 seconds, it starts watching your device automatically. While watching, the camera turns off and the screen blurs — press Touch ID to unlock when you're back.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("Start LurkAway at login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.set($0) }
            ))
            Text("Launches LurkAway automatically after you log in, so protection is always on.")
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
            Text("Trigger the alarm while watching when…")
                .font(.headline)

            Toggle("AC power disconnected", isOn: $settings.armWithPower)
                .disabled(isLastEnabled(settings.armWithPower))
            Toggle("Lid moved", isOn: $settings.armWithLid)
                .disabled(!lidSupported || isLastEnabled(settings.armWithLid && lidSupported))

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

    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Keep Mac awake with the lid closed while watching", isOn: Binding(
                get: { settings.keepAwakeWithLidClosed },
                set: { setKeepAwake($0) }
            ))
            .toggleStyle(.switch)

            Text("Normally macOS sleeps the moment the lid closes, so the alarm can't sound until the lid reopens. When enabled, LurkAway temporarily stops lid-close sleep while watching, so the siren keeps blasting. Sleep returns to normal the instant you unlock or stop watching.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if settings.keepAwakeWithLidClosed {
                authorizationStatus
            }

            Text("This needs a one-time administrator authorization to install a small helper that runs while watching. It only ever changes the lid-sleep setting, and reverts automatically if the app quits or crashes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .onAppear { daemonStatus = appState.sleepDaemon.status }
    }

    @ViewBuilder
    private var authorizationStatus: some View {
        switch daemonStatus {
        case .enabled:
            Label("Helper authorized and ready.", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .requiresApproval:
            VStack(alignment: .leading, spacing: 8) {
                Label("Waiting for approval in System Settings.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
                Button("Open Login Items Settings…") {
                    appState.sleepDaemon.openApprovalSettings()
                }
            }
        case .notRegistered:
            Label("Enabling will request authorization.", systemImage: "lock.fill")
                .foregroundStyle(.secondary)
                .font(.callout)
        case .unavailable:
            Label("Helper unavailable on this system.", systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    private func setKeepAwake(_ enabled: Bool) {
        settings.keepAwakeWithLidClosed = enabled
        settings.save()
        if enabled {
            daemonStatus = appState.sleepDaemon.register()
            if daemonStatus == .requiresApproval {
                appState.sleepDaemon.openApprovalSettings()
            }
        } else {
            Task {
                await appState.sleepDaemon.unregister()
                daemonStatus = appState.sleepDaemon.status
            }
        }
    }

    private var enabledSensorCount: Int {
        var count = 0
        if settings.armWithPower { count += 1 }
        if settings.armWithLid && lidSupported { count += 1 }
        return count
    }

    private func isLastEnabled(_ isThisOn: Bool) -> Bool {
        isThisOn && enabledSensorCount == 1
    }

    private var sensorFooter: String {
        var lines = ["At least one sensor must stay on. Both are near-zero power."]
        if !lidSupported {
            lines.append("The lid sensor isn't available on this device.")
        }
        return lines.joined(separator: " ")
    }
}

/// Brings the Settings window to the front and activates the (accessory) app when it opens.
private struct WindowActivator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = .floating
            window.collectionBehavior.insert(.moveToActiveSpace)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
