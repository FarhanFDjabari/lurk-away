import Foundation
import ServiceManagement
import os

/// App-side controller for the privileged sleep daemon: registers it via `SMAppService`,
/// holds the XPC connection, and keeps the "disable lid sleep" assertion alive with a
/// heartbeat. The daemon fails safe on its own, so this side is best-effort throughout.
@MainActor
final class SleepDaemonClient {
    enum Status {
        case notRegistered
        case requiresApproval
        case enabled
        case unavailable
    }

    private let plistName = "com.lurkaway.sleepd.plist"
    private let machServiceName = "com.lurkaway.sleepd"
    private static let heartbeatInterval: TimeInterval = 10

    private var connection: NSXPCConnection?
    private var heartbeatTimer: Timer?
    private var wantSleepDisabled = false

    private var service: SMAppService { SMAppService.daemon(plistName: plistName) }

    var status: Status {
        switch service.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unavailable
        @unknown default: return .unavailable
        }
    }

    // MARK: Registration

    /// Registers the daemon. On first use macOS surfaces an approval in System Settings.
    @discardableResult
    func register() -> Status {
        do {
            try service.register()
            log.notice("Sleep daemon registered — status=\(String(describing: self.status), privacy: .public)")
        } catch {
            // register() throws until the user approves the item; that's expected, not an error.
            if status == .requiresApproval {
                log.notice("Sleep daemon awaiting approval in System Settings")
            } else {
                log.error("Sleep daemon register failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return status
    }

    func unregister() async {
        do {
            try await service.unregister()
        } catch {
            log.error("Sleep daemon unregister failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: Control

    /// Ask the daemon to disable lid-close sleep and start keeping it alive.
    func disableSleep() {
        guard status == .enabled else {
            log.error("disableSleep skipped — daemon not enabled (status=\(String(describing: self.status), privacy: .public))")
            return
        }
        wantSleepDisabled = true
        sendDisable()
        startHeartbeat()
    }

    /// Revert to normal sleep behavior. Single app-side revert point (called from disarm).
    func enableSleep() {
        guard wantSleepDisabled else { return }
        wantSleepDisabled = false
        stopHeartbeat()
        proxy()?.enableLidSleep { _ in }
        teardownConnection()
    }

    // MARK: Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: Self.heartbeatInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func tick() {
        guard wantSleepDisabled else { return }
        proxy()?.heartbeat { _ in }
    }

    // MARK: XPC connection

    private func sendDisable() {
        proxy()?.disableLidSleep { _ in }
    }

    private func proxy() -> SleepControlProtocol? {
        ensureConnection().remoteObjectProxyWithErrorHandler { [weak self] _ in
            Task { @MainActor in self?.handleConnectionDrop() }
        } as? SleepControlProtocol
    }

    private func ensureConnection() -> NSXPCConnection {
        if let connection { return connection }
        let conn = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: SleepControlProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.handleConnectionDrop() }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in self?.handleConnectionDrop() }
        }
        conn.resume()
        connection = conn
        return conn
    }

    /// Connection lost. The daemon reverts to safe defaults on its own restart, so if we
    /// still want sleep disabled we must re-assert once a fresh connection is made.
    private func handleConnectionDrop() {
        teardownConnection()
        if wantSleepDisabled {
            sendDisable()
        }
    }

    private func teardownConnection() {
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
        connection = nil
    }
}
