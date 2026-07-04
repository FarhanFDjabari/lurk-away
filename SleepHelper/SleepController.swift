import Foundation

/// Root-privileged worker: toggles `pmset disablesleep` and guarantees the setting
/// reverts on explicit disable, client disconnect, or watchdog timeout.
final class SleepController: NSObject, SleepControlProtocol {
    private let queue = DispatchQueue(label: "com.lurkaway.sleepd.controller")
    private var watchdog: DispatchSourceTimer?
    private var sleepDisabled = false

    /// If the app stops sending heartbeats (crash/hang), revert after this long.
    private static let watchdogTimeout: TimeInterval = 30

    // MARK: SleepControlProtocol

    func disableLidSleep(withReply reply: @escaping (Bool) -> Void) {
        queue.async {
            let ok = self.setDisableSleep(true)
            if ok { self.armWatchdog() }
            reply(ok)
        }
    }

    func enableLidSleep(withReply reply: @escaping (Bool) -> Void) {
        queue.async {
            self.cancelWatchdog()
            reply(self.setDisableSleep(false))
        }
    }

    func heartbeat(withReply reply: @escaping (Bool) -> Void) {
        queue.async {
            if self.sleepDisabled { self.armWatchdog() }
            reply(true)
        }
    }

    // MARK: Backstops

    /// XPC connection dropped — the app died or lost contact. Fail safe.
    func clientDisconnected() {
        queue.async {
            guard self.sleepDisabled else { return }
            self.cancelWatchdog()
            _ = self.setDisableSleep(false)
        }
    }

    /// Force sleep back on at daemon launch to clear state left by an unclean shutdown.
    static func revertOnLaunch() {
        _ = runPmset(disable: false)
    }

    // MARK: Watchdog

    private func armWatchdog() {
        cancelWatchdog()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.watchdogTimeout)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.cancelWatchdog()
            _ = self.setDisableSleep(false)
        }
        timer.resume()
        watchdog = timer
    }

    private func cancelWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }

    // MARK: pmset

    @discardableResult
    private func setDisableSleep(_ disable: Bool) -> Bool {
        let ok = Self.runPmset(disable: disable)
        if ok { sleepDisabled = disable }
        return ok
    }

    @discardableResult
    private static func runPmset(disable: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-a", "disablesleep", disable ? "1" : "0"]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
