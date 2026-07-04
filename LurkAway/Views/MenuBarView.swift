import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isAlarming {
            Text("🚨 Caught someone!")
            Divider()
            Button("Unlock (Touch ID or password)") {
                Task { _ = await appState.attemptUnlock() }
            }
        } else {
            Button(appState.isArmed ? "🙈 I’m Back" : "👁 Watch My Mac") {
                appState.isArmed ? appState.disarm() : appState.arm()
            }
            .keyboardShortcut(appState.isArmed ? "s" : "w", modifiers: [.command])

            if appState.isArmed {
                Text("👁 Watching…")
                Button("🔔 Test Alarm") { appState.triggerAlarm(.manual) }
            }

            Divider()

            Toggle("Watch automatically when I walk away", isOn: Binding(
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
