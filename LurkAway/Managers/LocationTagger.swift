import CoreLocation
import os

/// Fetches a single coarse location fix, used to tag a tamper alert. Requests authorization
/// the first time it runs; returns nil if the user denies, the fix fails, or it times out.
@MainActor
final class LocationTagger: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var timeoutTask: Task<Void, Never>?

    private static let timeout: Duration = .seconds(4)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Prompts for authorization if not yet decided. Call when the user enables location
    /// tagging in Settings, so the system dialog appears in context — never during an alarm.
    func requestAuthorization() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// One-shot fix. Coarse accuracy keeps it fast and low-power. Never prompts — if
    /// authorization hasn't been granted yet, returns nil rather than interrupting the alarm.
    func currentFix() async -> CLLocation? {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        default:
            return nil
        }

        return await withCheckedContinuation { cont in
            continuation = cont
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: Self.timeout)
                self?.finish(nil)
            }
            manager.requestLocation()
        }
    }

    private func finish(_ location: CLLocation?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: location)
    }

    // MARK: - CLLocationManagerDelegate
    // Callbacks arrive on the run loop of the (main) thread that created the manager.

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated { finish(locations.last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            log.error("Location fix failed: \(error.localizedDescription, privacy: .public)")
            finish(nil)
        }
    }
}
