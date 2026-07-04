import SwiftUI
import AppKit

@MainActor
final class LockScreenManager {
    private var overlayWindows: [NSPanel] = []

    private static let topLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)

    /// Lower the overlay so the system Touch ID / password dialog appears on top and is usable,
    /// then raise it again if authentication fails.
    func setElevated(_ elevated: Bool) {
        let level: NSWindow.Level = elevated ? Self.topLevel : .normal
        for window in overlayWindows { window.level = level }
    }

    func show(message: String, onUnlock: @escaping () -> Void) {
        dismiss()

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = Self.topLevel
            panel.isOpaque = true
            panel.backgroundColor = .black
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.setFrame(screen.frame, display: true)

            panel.contentView = NSHostingView(rootView: OverlayView(message: message, onUnlock: onUnlock))
            panel.makeKeyAndOrderFront(nil)

            overlayWindows.append(panel)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }
}
