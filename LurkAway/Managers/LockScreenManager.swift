import SwiftUI
import AppKit

/// Borderless panel that is allowed to become key/main so it captures keyboard input,
/// preventing keystrokes from leaking to whatever window sits behind the lock overlay.
private final class LockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class LockScreenManager {
    private var overlayWindows: [LockPanel] = []
    private var priorPresentationOptions: NSApplication.PresentationOptions?

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

        // Block switching away (Cmd-Tab / Mission Control) so the lock can't be bypassed.
        priorPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.disableProcessSwitching, .disableHideApplication]

        // Activate the app and make the overlay the key window so it owns keyboard input;
        // keystrokes can no longer reach a text field behind the lock.
        NSApp.activate(ignoringOtherApps: true)
        for panel in overlayWindows { panel.orderFrontRegardless() }
        overlayWindows.first?.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        if let prior = priorPresentationOptions {
            NSApp.presentationOptions = prior
            priorPresentationOptions = nil
        }
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }
}
