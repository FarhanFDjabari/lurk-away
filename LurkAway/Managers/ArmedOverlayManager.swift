import SwiftUI
import AppKit
import os

/// Borderless panel that is allowed to become key/main so it captures keyboard input
/// while armed, preventing keystrokes from reaching the window behind the blur.
private final class ArmedPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Full-screen armed overlay: the live screen, blurred, with the faint watching eyes and
/// the "watching" capsule on top. Blocks interaction until the user disarms via Touch ID.
/// Same shape as `LockScreenManager`, but blurred instead of black.
@MainActor
final class ArmedOverlayManager {
    private var overlayWindows: [ArmedPanel] = []

    /// Above the menubar/status items so the overlay covers the whole screen and blocks
    /// interaction until the user disarms.
    private static let topLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)

    /// Lower the overlay so the system Touch ID / password dialog appears on top and is
    /// usable, then raise it again if authentication fails.
    func setElevated(_ elevated: Bool) {
        let level: NSWindow.Level = elevated ? Self.topLevel : .normal
        for window in overlayWindows { window.level = level }
    }

    func show(onDisarm: @escaping () -> Void) {
        guard overlayWindows.isEmpty else { return }

        for screen in NSScreen.screens {
            let panel = ArmedPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = Self.topLevel
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.setFrame(screen.frame, display: true)

            let blur = NSVisualEffectView()
            blur.blendingMode = .behindWindow
            blur.material = .fullScreenUI
            blur.state = .active
            blur.frame = panel.contentLayoutRect
            blur.autoresizingMask = [.width, .height]

            let hosting = NSHostingView(rootView: ArmedOverlayView(onDisarm: onDisarm))
            hosting.frame = blur.bounds
            hosting.autoresizingMask = [.width, .height]
            blur.addSubview(hosting)

            panel.contentView = blur
            overlayWindows.append(panel)
        }

        // Kiosk lockdown: presentation options only apply to a regular, active app, so
        // switch from accessory to regular first (restored in hide()). This suppresses the
        // menubar, Dock, Mission Control / app switching gestures, force-quit and logout.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [
            .hideDock, .hideMenuBar, .disableAppleMenu, .disableProcessSwitching,
            .disableForceQuit, .disableSessionTermination, .disableHideApplication
        ]
        for panel in overlayWindows { panel.orderFrontRegardless() }
        overlayWindows.first?.makeKeyAndOrderFront(nil)
        log.notice("Armed overlay shown on \(self.overlayWindows.count) screen(s)")
    }

    func hide() {
        NSApp.presentationOptions = []
        NSApp.setActivationPolicy(.accessory)
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }
}
