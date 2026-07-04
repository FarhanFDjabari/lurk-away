import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isAlarming {
            Label("Caught someone!", systemImage: "exclamationmark.triangle.fill")
            Divider()
            Button {
                Task { _ = await appState.attemptUnlock() }
            } label: {
                Label("Unlock (Touch ID or password)", systemImage: "lock.open.fill")
            }
        } else {
            Button {
                appState.isArmed ? appState.disarm() : appState.arm()
            } label: {
                Label(appState.isArmed ? "I’m Back" : "Watch My Mac",
                      systemImage: appState.isArmed ? "eye.slash.fill" : "eye.fill")
            }
            .keyboardShortcut(appState.isArmed ? "s" : "w", modifiers: [.command])

            if appState.isArmed {
                Label("Watching…", systemImage: "eye.fill")
                Button {
                    appState.triggerAlarm(.manual)
                } label: {
                    Label("Test Alarm", systemImage: "bell.fill")
                }
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

            SettingsLink { Label("Settings…", systemImage: "gearshape") }
                .keyboardShortcut(",", modifiers: [.command])

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit LurkAway", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}
