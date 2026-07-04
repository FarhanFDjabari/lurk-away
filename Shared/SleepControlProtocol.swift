import Foundation

/// XPC contract between the LurkAway app and the privileged sleep daemon.
/// Compiled into both the app and `com.lurkaway.sleepd`; the selectors must match.
@objc protocol SleepControlProtocol {
    func disableLidSleep(withReply reply: @escaping (Bool) -> Void)
    func enableLidSleep(withReply reply: @escaping (Bool) -> Void)
    func heartbeat(withReply reply: @escaping (Bool) -> Void)
}
