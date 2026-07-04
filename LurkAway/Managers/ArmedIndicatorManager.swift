import SwiftUI
import AppKit

/// Shows the faint, click-through "watching" indicator on every screen while armed.
@MainActor
final class ArmedIndicatorManager {
    private var windows: [NSPanel] = []

    func show() {
        guard windows.isEmpty else { return }

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true   // click-through: screen stays usable
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            panel.setFrame(screen.frame, display: true)
            panel.contentView = NSHostingView(rootView: ArmedIndicatorView())
            panel.orderFrontRegardless()
            windows.append(panel)
        }
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}
