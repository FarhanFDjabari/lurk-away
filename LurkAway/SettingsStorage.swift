import Foundation
import Combine

@MainActor
final class SettingsStorage: ObservableObject {
    @Published var lockMessage: String
    @Published var autoArmOnWalkAway: Bool
    @Published var armWithPower: Bool
    @Published var armWithLid: Bool
    @Published var keepAwakeWithLidClosed: Bool

    // Detection timings (v1.1.0)
    @Published var walkAwayDelaySeconds: Double
    @Published var lidSensitivityDegrees: Double
    @Published var sirenVolume: Double

    // Evidence & alerts (v1.1.0)
    @Published var captureEvidence: Bool
    @Published var tagLocation: Bool
    @Published var pushEnabled: Bool
    @Published var ntfyServer: String
    @Published var ntfyTopic: String
    @Published var ntfyEmail: String

    /// Consecutive no-face sample cycles (~1.5s each) before auto-arming.
    /// Rounded so the 5s default maps to 3 cycles, matching v1 behavior.
    var noFaceThreshold: Int { max(1, Int((walkAwayDelaySeconds / 1.5).rounded())) }

    init() {
        let defaults = UserDefaults.standard
        self.lockMessage = defaults.string(forKey: "lockMessage") ?? SettingsStorage.defaultMessage
        self.autoArmOnWalkAway = defaults.object(forKey: "autoArmOnWalkAway") as? Bool ?? true
        self.armWithPower = defaults.object(forKey: "armWithPower") as? Bool ?? true
        self.armWithLid = defaults.object(forKey: "armWithLid") as? Bool ?? true
        self.keepAwakeWithLidClosed = defaults.object(forKey: "keepAwakeWithLidClosed") as? Bool ?? false
        self.walkAwayDelaySeconds = defaults.object(forKey: "walkAwayDelaySeconds") as? Double ?? 5.0
        self.lidSensitivityDegrees = defaults.object(forKey: "lidSensitivityDegrees") as? Double ?? 5.0
        self.sirenVolume = defaults.object(forKey: "sirenVolume") as? Double ?? 1.0
        self.captureEvidence = defaults.object(forKey: "captureEvidence") as? Bool ?? true
        self.tagLocation = defaults.object(forKey: "tagLocation") as? Bool ?? false
        self.pushEnabled = defaults.object(forKey: "pushEnabled") as? Bool ?? false
        self.ntfyServer = defaults.string(forKey: "ntfyServer") ?? "https://ntfy.sh"
        self.ntfyTopic = defaults.string(forKey: "ntfyTopic") ?? ""
        self.ntfyEmail = defaults.string(forKey: "ntfyEmail") ?? ""
    }

    func save() {
        let d = UserDefaults.standard
        d.set(lockMessage, forKey: "lockMessage")
        d.set(autoArmOnWalkAway, forKey: "autoArmOnWalkAway")
        d.set(armWithPower, forKey: "armWithPower")
        d.set(armWithLid, forKey: "armWithLid")
        d.set(keepAwakeWithLidClosed, forKey: "keepAwakeWithLidClosed")
        d.set(walkAwayDelaySeconds, forKey: "walkAwayDelaySeconds")
        d.set(lidSensitivityDegrees, forKey: "lidSensitivityDegrees")
        d.set(sirenVolume, forKey: "sirenVolume")
        d.set(captureEvidence, forKey: "captureEvidence")
        d.set(tagLocation, forKey: "tagLocation")
        d.set(pushEnabled, forKey: "pushEnabled")
        d.set(ntfyServer, forKey: "ntfyServer")
        d.set(ntfyTopic, forKey: "ntfyTopic")
        d.set(ntfyEmail, forKey: "ntfyEmail")
    }

    static let defaultMessage = """
    This device is protected by LurkAway.
    If you are not the owner, please return this device immediately.
    An alarm notification has been sent to the owner with this location.
    """
}
