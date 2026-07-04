import Foundation
import IOKit.ps

/// Detects the AC adapter being unplugged — a common first move by a thief grabbing a laptop.
/// Uses the documented IOKit power-source notification API.
@MainActor
final class PowerMonitor {
    var onUnplug: (() -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var wasPluggedIn = true

    func start() {
        stop()
        wasPluggedIn = Self.isPluggedIn()

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.evaluate() }
        }, context)?.takeRetainedValue() else {
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }

    private func evaluate() {
        let pluggedIn = Self.isPluggedIn()
        if wasPluggedIn, !pluggedIn {
            onUnplug?()
        }
        wasPluggedIn = pluggedIn
    }

    static func isPluggedIn() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return true
        }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  let state = desc[kIOPSPowerSourceStateKey] as? String else {
                continue
            }
            return state == kIOPSACPowerValue
        }
        return true   // No internal battery (e.g. desktop) — treat as always powered.
    }
}
