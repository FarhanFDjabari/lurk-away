import Foundation
import Combine
import os

/// Coordinates the triggers active while armed. The user chooses which run:
/// - `PowerMonitor`: AC adapter unplugged.
/// - `LidAngleMonitor`: laptop lid moved.
/// - `ArmedCameraScanner`: pulse camera for tamper motion and owner-return recognition.
/// Any enabled tamper source raises `onMotion`; recognizing the owner raises `onOwnerReturn`.
@MainActor
final class MotionMonitor: ObservableObject {
    @Published var motionDetected = false

    var onMotion: (() -> Void)?
    var onOwnerReturn: (() -> Void)?
    var sensitivity: Double = 0.5 {
        didSet { scanner.sensitivity = sensitivity }
    }

    var usePower = true
    var useLid = true
    var useCamera = true
    var autoDisarmOnReturn = false

    private let power = PowerMonitor()
    private let lid = LidAngleMonitor()
    private let scanner = ArmedCameraScanner()

    init() {
        power.onUnplug = { [weak self] in self?.fire() }
        lid.onLidChange = { [weak self] in self?.fire() }
        scanner.onMotion = { [weak self] in self?.fire() }
        scanner.onOwnerReturn = { [weak self] in
            log.notice("Owner recognized — auto-disarming")
            self?.onOwnerReturn?()
        }
    }

    func start() {
        motionDetected = false
        scanner.sensitivity = sensitivity
        if usePower { power.start() }
        if useLid { lid.start() }
        if useCamera || autoDisarmOnReturn {
            scanner.start(motion: useCamera, faceReturn: autoDisarmOnReturn)
        }
    }

    func stop() {
        power.stop()
        lid.stop()
        scanner.stop()
    }

    private func fire() {
        guard !motionDetected else { return }
        motionDetected = true
        stop()
        onMotion?()
    }
}
