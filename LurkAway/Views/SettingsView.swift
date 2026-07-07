import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStorage
    @EnvironmentObject var appState: AppState
    @StateObject private var launchAtLogin = LaunchAtLogin()
    @State private var lidSupported = LidAngleMonitor.isSupported()
    @State private var daemonStatus: SleepDaemonClient.Status = .notRegistered

    @State private var ntfyToken = ""
    @State private var evidenceCount = 0
    @State private var showClearConfirm = false
    @State private var isSendingTest = false
    @State private var testResult: String?

    private static let guideURL = URL(string: "https://github.com/FarhanFDjabari/LurkAway/blob/main/docs/ntfy-setup.md")!

    var body: some View {
        TabView {
            protectionTab
                .tabItem { Label("Protection", systemImage: "shield") }
            sensorsTab
                .tabItem { Label("Sensors", systemImage: "sensor.tag.radiowaves.forward") }
            detectionTab
                .tabItem { Label("Detection", systemImage: "slider.horizontal.3") }
            alarmTab
                .tabItem { Label("Alarm", systemImage: "speaker.wave.3") }
            alertsTab
                .tabItem { Label("Alerts", systemImage: "bell.badge") }
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

    private var detectionTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Arm after \(settings.walkAwayDelaySeconds, specifier: "%.1f")s away")
                    .font(.headline)
                Slider(value: $settings.walkAwayDelaySeconds, in: 2...15, step: 0.5) { editing in
                    if !editing { settings.save() }
                }
                Text("How long your face must be gone before LurkAway starts watching automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Lid movement threshold \(settings.lidSensitivityDegrees, specifier: "%.0f")°")
                    .font(.headline)
                Slider(value: $settings.lidSensitivityDegrees, in: 2...30, step: 1) { editing in
                    if !editing { settings.save() }
                }
                .disabled(!lidSupported)
                Text(lidSupported
                     ? "How far the lid must move from its armed position to trigger the alarm. Lower is more sensitive."
                     : "The lid sensor isn't available on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Siren volume \(Int(settings.sirenVolume * 100))%")
                    .font(.headline)
                Slider(value: $settings.sirenVolume, in: 0.1...1.0) { editing in
                    if !editing { settings.save() }
                }
                Text("Loudness of LurkAway's own siren. The system output is still forced audible and can't be muted while locked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
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

    private var alertsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Capture a photo on tamper (saved on this Mac)", isOn: $settings.captureEvidence)
                    .toggleStyle(.switch)
                Text("A small photo of whoever is at the device is saved locally when the alarm fires. It's never uploaded unless you also enable remote alerts below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Tag alerts with location", isOn: Binding(
                    get: { settings.tagLocation },
                    set: { setTagLocation($0) }
                ))
                .toggleStyle(.switch)
                Text("Records where your Mac was when the alarm fired. Asks for location permission the first time you enable it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                remoteAlertSection
                Divider()
                storedEvidenceSection
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
        .onAppear {
            ntfyToken = KeychainStore.get(account: KeychainStore.ntfyTokenAccount) ?? ""
            evidenceCount = EvidenceStore.itemCount()
        }
    }

    @ViewBuilder
    private var remoteAlertSection: some View {
        Text("Remote alert (leaves this Mac)")
            .font(.headline)
        Toggle("Send a push notification on tamper", isOn: $settings.pushEnabled)
            .toggleStyle(.switch)

        if settings.pushEnabled {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Server") {
                    TextField("https://ntfy.sh", text: $settings.ntfyServer)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Topic") {
                    HStack {
                        TextField("your private topic", text: $settings.ntfyTopic)
                            .textFieldStyle(.roundedBorder)
                        Button("Generate") { generateTopic() }
                    }
                }
                Text("Subscribe by opening the topic URL in a browser or the ntfy app. See the setup guide.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Email (optional)") {
                    TextField("you@example.com", text: $settings.ntfyEmail)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Also email me the alert (text only, no photo).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Token (optional)") {
                    SecureField("for self-hosted / authed servers", text: $ntfyToken)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: ntfyToken) { _, newValue in
                            KeychainStore.set(newValue, account: KeychainStore.ntfyTokenAccount)
                        }
                }

                HStack {
                    Button("Send test") { sendTest() }
                        .disabled(isSendingTest || settings.ntfyTopic.trimmingCharacters(in: .whitespaces).isEmpty)
                    if isSendingTest { ProgressView().controlSize(.small) }
                    if let testResult { Text(testResult).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Link("How to set up…", destination: Self.guideURL)
                        .font(.caption)
                }

                Text("Enabling remote alerts sends the notification — and, in topic mode, the photo — to the configured ntfy server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        }
    }

    @ViewBuilder
    private var storedEvidenceSection: some View {
        Text("Stored evidence")
            .font(.headline)
        Text(evidenceCount == 0 ? "No photos stored." : "^[\(evidenceCount) photo](inflect: true) stored on this Mac.")
            .font(.callout)
            .foregroundStyle(.secondary)
        HStack {
            Button("Reveal in Finder") { revealEvidence() }
                .disabled(evidenceCount == 0)
            Button("Clear all evidence…", role: .destructive) { showClearConfirm = true }
                .disabled(evidenceCount == 0)
        }
        .confirmationDialog(
            "Delete all \(evidenceCount) stored photos? This can't be undone.",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) { clearEvidence() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func setTagLocation(_ enabled: Bool) {
        settings.tagLocation = enabled
        settings.save()
        if enabled { appState.evidenceReporter.requestLocationAuthorization() }
    }

    private func generateTopic() {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let suffix = String((0..<20).map { _ in chars.randomElement()! })
        settings.ntfyTopic = "lurkaway-\(suffix)"
        settings.save()
    }

    private func sendTest() {
        isSendingTest = true
        testResult = nil
        let alert = NotificationSender.Alert(
            title: "LurkAway test",
            message: "This is a test alert from LurkAway.",
            jpeg: nil,
            filename: "test.jpg",
            email: settings.ntfyEmail.isEmpty ? nil : settings.ntfyEmail
        )
        let server = settings.ntfyServer
        let topic = settings.ntfyTopic
        let token = ntfyToken.isEmpty ? nil : ntfyToken
        Task {
            let ok = await NotificationSender().send(alert, server: server, topic: topic, token: token)
            isSendingTest = false
            testResult = ok ? "Sent." : "Failed — check server/topic."
        }
    }

    private func revealEvidence() {
        NSWorkspace.shared.open(EvidenceStore.directoryURL)
    }

    private func clearEvidence() {
        do {
            try EvidenceStore.clearAll()
        } catch {
            testResult = "Couldn't delete: \(error.localizedDescription)"
        }
        evidenceCount = EvidenceStore.itemCount()
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
