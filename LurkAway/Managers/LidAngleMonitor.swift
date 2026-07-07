import Foundation
import IOKit.hid

/// Detects the laptop lid being moved by polling the Apple Silicon lid-angle sensor
/// (SPU HID, sensor usage page, usage 0x047F reports the hinge angle in degrees).
/// A change beyond `thresholdDegrees` from the armed baseline raises `onLidChange`.
@MainActor
final class LidAngleMonitor {
    var onLidChange: (() -> Void)?

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var element: IOHIDElement?
    private var timer: Timer?
    private var baseline: Double?

    var thresholdDegrees = 5.0
    private nonisolated static let sensorUsagePage = 0x20
    private nonisolated static let lidAngleUsage = 0x047F
    private nonisolated static let pollInterval: TimeInterval = 0.3

    private nonisolated(unsafe) static var cachedSupport: Bool?

    /// Whether this Mac exposes a readable lid-angle sensor (false on desktops / clamshell setups).
    /// Probed once with a self-contained IOKit check (no instance, so nothing to deinit).
    static func isSupported() -> Bool {
        if let cached = cachedSupport { return cached }
        let supported = probeLidSensor()
        cachedSupport = supported
        return supported
    }

    private nonisolated static func probeLidSensor() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDDeviceUsagePageKey: sensorUsagePage] as CFDictionary)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return false }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return false }
        for device in devices {
            guard let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] else { continue }
            if elements.contains(where: {
                IOHIDElementGetUsagePage($0) == UInt32(sensorUsagePage) && IOHIDElementGetUsage($0) == UInt32(lidAngleUsage)
            }) {
                return true
            }
        }
        return false
    }

    func start() {
        stop()
        guard openSensor(), let angle = readAngle() else { return }
        baseline = angle
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        baseline = nil
        element = nil
        device = nil
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
    }

    private func poll() {
        guard let baseline, let angle = readAngle() else { return }
        if abs(angle - baseline) > thresholdDegrees {
            onLidChange?()
        }
    }

    private func openSensor() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDDeviceUsagePageKey: Self.sensorUsagePage] as CFDictionary)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }

        for candidate in devices {
            guard let elements = IOHIDDeviceCopyMatchingElements(candidate, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] else {
                continue
            }
            if let lidElement = elements.first(where: {
                IOHIDElementGetUsagePage($0) == UInt32(Self.sensorUsagePage) &&
                IOHIDElementGetUsage($0) == UInt32(Self.lidAngleUsage)
            }) {
                self.manager = manager
                self.device = candidate
                self.element = lidElement
                return true
            }
        }

        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        return false
    }

    private func readAngle() -> Double? {
        guard let device, let element else { return nil }
        let valuePtr = UnsafeMutablePointer<Unmanaged<IOHIDValue>>.allocate(capacity: 1)
        defer { valuePtr.deallocate() }
        guard IOHIDDeviceGetValue(device, element, valuePtr) == kIOReturnSuccess else { return nil }
        let angle = IOHIDValueGetScaledValue(valuePtr.pointee.takeUnretainedValue(),
                                             IOHIDValueScaleType(kIOHIDValueScaleTypePhysical))
        return angle.isNaN ? nil : angle
    }
}
