import IOKit.pwr_mgt

/// Holds a power assertion while armed so the system won't idle-sleep and suspend the
/// sensors. Note: this prevents *idle* system sleep only — closing the lid still forces
/// clamshell sleep, which macOS enforces at the hardware level and cannot be overridden
/// without a root helper.
@MainActor
final class SleepGuard {
    private var assertionID: IOPMAssertionID = 0
    private var isActive = false

    func begin(reason: String) {
        guard !isActive else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        isActive = (result == kIOReturnSuccess)
    }

    func end() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }
}
