import Foundation
import Combine

@MainActor
final class SettingsStorage: ObservableObject {
    @Published var lockMessage: String
    @Published var autoArmOnWalkAway: Bool
    @Published var motionSensitivity: Double
    @Published var armWithPower: Bool
    @Published var armWithLid: Bool
    @Published var armWithCamera: Bool
    @Published var autoDisarmOnReturn: Bool

    init() {
        let defaults = UserDefaults.standard
        self.lockMessage = defaults.string(forKey: "lockMessage") ?? SettingsStorage.defaultMessage
        self.autoArmOnWalkAway = defaults.object(forKey: "autoArmOnWalkAway") as? Bool ?? true
        self.motionSensitivity = defaults.object(forKey: "motionSensitivity") as? Double ?? 0.5
        self.armWithPower = defaults.object(forKey: "armWithPower") as? Bool ?? true
        self.armWithLid = defaults.object(forKey: "armWithLid") as? Bool ?? true
        self.armWithCamera = defaults.object(forKey: "armWithCamera") as? Bool ?? true
        self.autoDisarmOnReturn = defaults.object(forKey: "autoDisarmOnReturn") as? Bool ?? false
    }

    func save() {
        let d = UserDefaults.standard
        d.set(lockMessage, forKey: "lockMessage")
        d.set(autoArmOnWalkAway, forKey: "autoArmOnWalkAway")
        d.set(motionSensitivity, forKey: "motionSensitivity")
        d.set(armWithPower, forKey: "armWithPower")
        d.set(armWithLid, forKey: "armWithLid")
        d.set(armWithCamera, forKey: "armWithCamera")
        d.set(autoDisarmOnReturn, forKey: "autoDisarmOnReturn")
    }

    static let defaultMessage = """
    This MacBook is protected by LurkAway.
    If you are not the owner, please return this device immediately.
    An alarm notification has been sent to the owner with this location.
    """
}
