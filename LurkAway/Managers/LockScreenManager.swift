import SwiftUI
import AppKit
import os

/// Borderless panel that is allowed to become key/main so it captures keyboard input,
/// preventing keystrokes from leaking to whatever window sits behind the lock overlay.
private final class LockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class LockScreenManager {
    private var overlayWindows: [LockPanel] = []

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
            let panel = LockPanel(
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
            overlayWindows.append(panel)
        }

        // Kiosk lockdown (same as the armed overlay): presentation options only apply to a
        // regular, active app, so switch from accessory to regular first (restored in
        // dismiss()). Suppresses menubar, Dock, Mission Control / app switching, force-quit
        // and logout so the lock can't be escaped.
        NSApp.setActivationPolicy(.regular)
        // Show first, then take key focus so keystrokes can't reach a window behind the lock.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [
            .hideDock, .hideMenuBar, .disableAppleMenu, .disableProcessSwitching,
            .disableForceQuit, .disableSessionTermination, .disableHideApplication
        ]
        for panel in overlayWindows { panel.orderFrontRegardless() }
        overlayWindows.first?.makeKeyAndOrderFront(nil)
        log.notice("Lock overlay shown on \(self.overlayWindows.count) screen(s)")
    }

    func dismiss() {
        NSApp.presentationOptions = []
        NSApp.setActivationPolicy(.accessory)
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }
}
