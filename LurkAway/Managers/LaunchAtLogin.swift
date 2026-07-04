import ServiceManagement
import Combine
import os

/// Registers the app as a macOS login item via SMAppService so it starts right after boot.
/// SMAppService is the source of truth; `isEnabled` mirrors its current status.
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled: Bool

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            log.error("Launch-at-login \(enabled ? "enable" : "disable", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }
}
