import Foundation
import Combine

/// Coordinates the tamper triggers active while armed (camera stays off while armed to save
/// power — the owner disarms manually on return, guided by the on-screen indicator):
/// - `PowerMonitor`: AC adapter unplugged.
/// - `LidAngleMonitor`: laptop lid moved.
/// Either firing raises `onMotion`.
@MainActor
final class MotionMonitor: ObservableObject {
    @Published var motionDetected = false

    var onMotion: (() -> Void)?

    var usePower = true
    var useLid = true
    var lidSensitivityDegrees = 5.0

    private let power = PowerMonitor()
    private let lid = LidAngleMonitor()

    init() {
        power.onUnplug = { [weak self] in self?.fire() }
        lid.onLidChange = { [weak self] in self?.fire() }
    }

    func start() {
        motionDetected = false
        if usePower { power.start() }
        if useLid {
            lid.thresholdDegrees = lidSensitivityDegrees
            lid.start()
        }
    }

    func stop() {
        power.stop()
        lid.stop()
    }

    private func fire() {
        guard !motionDetected else { return }
        motionDetected = true
        stop()
        onMotion?()
    }
}
