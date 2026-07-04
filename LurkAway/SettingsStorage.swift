import Foundation
import Combine

@MainActor
final class SettingsStorage: ObservableObject {
    @Published var lockMessage: String
    @Published var autoArmOnWalkAway: Bool
    @Published var armWithPower: Bool
    @Published var armWithLid: Bool

    init() {
        let defaults = UserDefaults.standard
        self.lockMessage = defaults.string(forKey: "lockMessage") ?? SettingsStorage.defaultMessage
        self.autoArmOnWalkAway = defaults.object(forKey: "autoArmOnWalkAway") as? Bool ?? true
        self.armWithPower = defaults.object(forKey: "armWithPower") as? Bool ?? true
        self.armWithLid = defaults.object(forKey: "armWithLid") as? Bool ?? true
    }

    func save() {
        let d = UserDefaults.standard
        d.set(lockMessage, forKey: "lockMessage")
        d.set(autoArmOnWalkAway, forKey: "autoArmOnWalkAway")
        d.set(armWithPower, forKey: "armWithPower")
        d.set(armWithLid, forKey: "armWithLid")
    }

    static let defaultMessage = """
    This MacBook is protected by LurkAway.
    If you are not the owner, please return this device immediately.
    An alarm notification has been sent to the owner with this location.
    """
}
