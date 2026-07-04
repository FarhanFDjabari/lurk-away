import Foundation
import Combine
import AppKit
import os

enum AlarmTrigger: String {
    case manual = "Manual"
    case motionDetected = "Motion detected"
    case faceAway = "Walk-away detected"
}

@MainActor
final class AppState: ObservableObject {
    @Published var isArmed = false
    @Published var isAlarming = false
    @Published var currentTrigger: AlarmTrigger?

    let faceDetection = FaceDetectionManager()
    let motionMonitor = MotionMonitor()
    let alarm = AlarmController()
    let lockScreen = LockScreenManager()
    let biometrics = BiometricManager()
    let settings = SettingsStorage()

    private let sleepGuard = SleepGuard()

    private var cancellables = Set<AnyCancellable>()

    init() {
        faceDetection.onWalkAway = { [weak self] in
            self?.arm(trigger: .faceAway)
        }

        motionMonitor.onMotion = { [weak self] in
            self?.triggerAlarm(.motionDetected)
        }

        alarm.$isPlaying
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                guard let self, !playing else { return }
                self.isAlarming = false
                self.currentTrigger = nil
                self.lockScreen.dismiss()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isAlarming else { return }
                self.presentLockScreen()
            }
            .store(in: &cancellables)

        if settings.autoArmOnWalkAway {
            faceDetection.start()
        }
    }

    func arm(trigger: AlarmTrigger = .manual) {
        guard !isArmed else { return }
        isArmed = true
        currentTrigger = trigger
        log.notice("ARMED (\(trigger.rawValue, privacy: .public)) — power=\(self.settings.armWithPower) lid=\(self.settings.armWithLid) camera=\(self.settings.armWithCamera)")
        faceDetection.stop()
        sleepGuard.begin(reason: "LurkAway is armed")
        motionMonitor.sensitivity = settings.motionSensitivity
        motionMonitor.usePower = settings.armWithPower
        motionMonitor.useLid = settings.armWithLid
        motionMonitor.useCamera = settings.armWithCamera
        motionMonitor.start()
    }

    func disarm() {
        isArmed = false
        currentTrigger = nil
        log.notice("DISARMED")
        sleepGuard.end()
        motionMonitor.stop()
        if settings.autoArmOnWalkAway {
            faceDetection.start()
        }
    }

    func triggerAlarm(_ trigger: AlarmTrigger) {
        guard !isAlarming else { return }
        isAlarming = true
        currentTrigger = trigger
        log.error("ALARM TRIGGERED — \(trigger.rawValue, privacy: .public)")
        motionMonitor.stop()
        alarm.play()
        presentLockScreen()
    }

    func attemptUnlock() async -> Bool {
        log.notice("Unlock requested — awaiting Touch ID/password")
        guard await biometrics.authenticate(reason: "Unlock LurkAway to stop the alarm") else {
            log.error("Unlock FAILED")
            return false
        }
        log.notice("Unlock SUCCEEDED — stopping alarm")
        alarm.stop()
        disarm()
        return true
    }

    private func presentLockScreen() {
        lockScreen.show(message: settings.lockMessage) { [weak self] in
            Task { @MainActor in _ = await self?.attemptUnlock() }
        }
    }
}
