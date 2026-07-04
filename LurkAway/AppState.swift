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

    private var isAuthenticating = false

    let faceDetection = FaceDetectionManager()
    let motionMonitor = MotionMonitor()
    let alarm = AlarmController()
    let lockScreen = LockScreenManager()
    let biometrics = BiometricManager()
    let settings = SettingsStorage()

    private let sleepGuard = SleepGuard()
    private let armedOverlay = ArmedOverlayManager()

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
        log.notice("ARMED (\(trigger.rawValue, privacy: .public)) — power=\(self.settings.armWithPower) lid=\(self.settings.armWithLid)")
        faceDetection.stop()
        sleepGuard.begin(reason: "LurkAway is armed")
        presentArmedOverlay()
        motionMonitor.usePower = settings.armWithPower
        motionMonitor.useLid = settings.armWithLid
        motionMonitor.start()
    }

    func disarm() {
        isArmed = false
        currentTrigger = nil
        log.notice("DISARMED")
        sleepGuard.end()
        armedOverlay.hide()
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
        armedOverlay.hide()
        motionMonitor.stop()
        alarm.play()
        presentLockScreen()
    }

    func attemptUnlock() async -> Bool {
        guard !isAuthenticating else { return false }   // one prompt at a time
        isAuthenticating = true
        defer { isAuthenticating = false }

        log.notice("Unlock requested — awaiting Touch ID/password")
        lockScreen.setElevated(false)   // let the system password dialog show above the overlay
        guard await biometrics.authenticate(reason: "Unlock LurkAway to stop the alarm") else {
            log.error("Unlock FAILED/cancelled")
            lockScreen.setElevated(true)
            return false
        }
        log.notice("Unlock SUCCEEDED — stopping alarm")
        alarm.stop()
        disarm()
        return true
    }

    func attemptDisarm() async -> Bool {
        guard isArmed, !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }

        log.notice("Disarm requested — awaiting Touch ID/password")
        armedOverlay.setElevated(false)   // let the system password dialog show above the overlay
        guard await biometrics.authenticate(reason: "Unlock LurkAway to use your device") else {
            log.error("Disarm FAILED/cancelled")
            armedOverlay.setElevated(true)
            return false
        }
        log.notice("Disarm SUCCEEDED")
        disarm()
        return true
    }

    private func presentArmedOverlay() {
        // No auto-prompt: the system Touch ID dialog only appears when the owner presses
        // Unlock on the overlay (or the menubar item).
        armedOverlay.show { [weak self] in
            Task { @MainActor in _ = await self?.attemptDisarm() }
        }
    }

    private func presentLockScreen() {
        // No auto-prompt: the system Touch ID dialog only appears when the user presses
        // Unlock on the overlay (or the menubar item).
        lockScreen.show(message: settings.lockMessage) { [weak self] in
            Task { @MainActor in _ = await self?.attemptUnlock() }
        }
    }
}
