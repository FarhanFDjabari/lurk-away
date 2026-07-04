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
    private let armedIndicator = ArmedIndicatorManager()
    private let faceEnroller = FaceEnroller()

    private var cancellables = Set<AnyCancellable>()

    init() {
        faceDetection.onWalkAway = { [weak self] in
            self?.arm(trigger: .faceAway)
        }

        motionMonitor.onMotion = { [weak self] in
            self?.triggerAlarm(.motionDetected)
        }

        // Owner recognized while watching (pre-alarm only) -> stand down.
        motionMonitor.onOwnerReturn = { [weak self] in
            guard let self, self.isArmed, !self.isAlarming else { return }
            self.disarm()
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

        // Start/stop walk-away watching whenever the setting changes, from the menu or Settings.
        settings.$autoArmOnWalkAway
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                self.settings.save()
                if enabled, !self.isArmed, !self.isAlarming {
                    self.faceDetection.start()
                } else if !enabled {
                    self.faceDetection.stop()
                }
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
        armedIndicator.show()
        motionMonitor.sensitivity = settings.motionSensitivity
        motionMonitor.usePower = settings.armWithPower
        motionMonitor.useLid = settings.armWithLid
        motionMonitor.useCamera = settings.armWithCamera
        motionMonitor.autoDisarmOnReturn = settings.autoDisarmOnReturn && FaceRecognizer.isEnrolled
        motionMonitor.start()
    }

    func disarm() {
        isArmed = false
        currentTrigger = nil
        log.notice("DISARMED")
        sleepGuard.end()
        armedIndicator.hide()
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
        armedIndicator.hide()
        motionMonitor.stop()
        alarm.play()
        presentLockScreen()
    }

    func attemptUnlock() async -> Bool {
        log.notice("Unlock requested — awaiting Touch ID/password")
        lockScreen.setElevated(false)   // let the system password dialog show above the overlay
        guard await biometrics.authenticate(reason: "Unlock LurkAway to stop the alarm") else {
            log.error("Unlock FAILED")
            lockScreen.setElevated(true)
            return false
        }
        log.notice("Unlock SUCCEEDED — stopping alarm")
        alarm.stop()
        disarm()
        return true
    }

    func enrollFace() async -> Bool {
        faceDetection.stop()
        let success = await withCheckedContinuation { continuation in
            faceEnroller.enroll { continuation.resume(returning: $0) }
        }
        if settings.autoArmOnWalkAway, !isArmed { faceDetection.start() }
        return success
    }

    private func presentLockScreen() {
        lockScreen.show(message: settings.lockMessage) { [weak self] in
            Task { @MainActor in _ = await self?.attemptUnlock() }
        }
    }
}
