import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStorage
    @EnvironmentObject var appState: AppState
    @State private var lidSupported = LidAngleMonitor.isSupported()
    @State private var faceEnrolled = FaceRecognizer.isEnrolled
    @State private var enrolling = false
    @State private var enrollFailed = false

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
            Toggle("Watch automatically when I walk away", isOn: $settings.autoArmOnWalkAway)
            Text("When enabled, LurkAway watches for your face. When you look away and no face is seen for about 5 seconds, it starts watching your Mac automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 4)

            Text("Recognize me")
                .font(.headline)
            Toggle("Stand down automatically when it recognizes my face", isOn: $settings.autoDisarmOnReturn)
                .disabled(!faceEnrolled)

            HStack(spacing: 10) {
                if enrolling {
                    ProgressView().controlSize(.small)
                    Text("Look at the camera…").foregroundStyle(.secondary)
                } else {
                    Button(faceEnrolled ? "Re-enroll face" : "Enroll my face", action: enroll)
                    if faceEnrolled {
                        Button("Remove", role: .destructive) {
                            FaceRecognizer.clear()
                            faceEnrolled = false
                            settings.autoDisarmOnReturn = false
                            settings.save()
                        }
                    }
                    Label(faceEnrolled ? "Face enrolled" : "Not enrolled",
                          systemImage: faceEnrolled ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
                        .foregroundStyle(faceEnrolled ? .green : .secondary)
                }
            }
            if enrollFailed {
                Text("Couldn't capture your face — make sure it's well-lit and centered, then try again.")
                    .font(.caption).foregroundStyle(.red)
            }
            Text("Face matching can be fooled by a photo, so this only stands down while watching — stopping a live alarm always needs Touch ID or your password.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    private func enroll() {
        enrollFailed = false
        enrolling = true
        Task {
            let success = await appState.enrollFace()
            enrolling = false
            faceEnrolled = FaceRecognizer.isEnrolled
            enrollFailed = !success
            if faceEnrolled, success { settings.autoDisarmOnReturn = true; settings.save() }
        }
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
            guard let window = view.window else { return }
            // Float above other apps so reopening Settings always brings it to the front,
            // even when the accessory app isn't the active one.
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
