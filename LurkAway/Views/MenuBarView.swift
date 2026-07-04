import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isAlarming {
            Text("🚨 ALARM ACTIVE")
            Divider()
            Button("Unlock with Touch ID") {
                Task { _ = await appState.attemptUnlock() }
            }
        } else {
            Button(appState.isArmed ? "🔒 Disarm" : "🛡 Arm Now") {
                appState.isArmed ? appState.disarm() : appState.arm()
            }
            .keyboardShortcut(appState.isArmed ? "d" : "a", modifiers: [.command])

            if appState.isArmed {
                Button("🔔 Test Alarm") { appState.triggerAlarm(.manual) }
            }

            Divider()

            Toggle("Auto-arm when I walk away", isOn: Binding(
                get: { appState.settings.autoArmOnWalkAway },
                set: {
                    appState.settings.autoArmOnWalkAway = $0
                    appState.settings.save()
                    if $0, !appState.isArmed { appState.faceDetection.start() }
                    else { appState.faceDetection.stop() }
                }
            ))

            Divider()

            SettingsLink { Text("Settings...") }
                .keyboardShortcut(",", modifiers: [.command])

            Button("Quit LurkAway") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: [.command])
        }
    }
}
