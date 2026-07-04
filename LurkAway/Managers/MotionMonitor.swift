import Foundation
import Combine

/// Coordinates the tamper triggers active while armed. The user chooses which run:
/// - `PowerMonitor`: AC adapter unplugged.
/// - `LidAngleMonitor`: laptop lid moved (hinge angle changes).
/// - `OpticalMotionDetector`: front-camera scene lurches when the laptop is moved.
/// Any enabled detector firing raises `onMotion`.
@MainActor
final class MotionMonitor: ObservableObject {
    @Published var motionDetected = false

    var onMotion: (() -> Void)?
    var sensitivity: Double = 0.5 {
        didSet { optical.sensitivity = sensitivity }
    }

    var usePower = true
    var useLid = true
    var useCamera = true

    private let power = PowerMonitor()
    private let lid = LidAngleMonitor()
    private let optical = OpticalMotionDetector()

    init() {
        power.onUnplug = { [weak self] in self?.fire() }
        lid.onLidChange = { [weak self] in self?.fire() }
        optical.onMotion = { [weak self] in self?.fire() }
    }

    func start() {
        motionDetected = false
        if usePower { power.start() }
        if useLid { lid.start() }
        if useCamera {
            optical.sensitivity = sensitivity
            optical.start()
        }
    }

    func stop() {
        power.stop()
        lid.stop()
        optical.stop()
    }

    private func fire() {
        guard !motionDetected else { return }
        motionDetected = true
        stop()
        onMotion?()
    }
}
