import Foundation
import CoreLocation

/// Orchestrates tamper evidence: grabs a snapshot and a location fix concurrently (each gated
/// on its setting), persists them via `EvidenceStore`, and returns the record for delivery.
@MainActor
final class EvidenceReporter {
    struct Evidence {
        let jpegURL: URL?
        let jpeg: Data?
        let location: CLLocation?
        let trigger: AlarmTrigger
        let date: Date
    }

    private let camera = EvidenceCaptureManager()
    private let locationTagger = LocationTagger()
    private let sender = NotificationSender()

    /// Requests location authorization in context, when the user enables tagging in Settings.
    func requestLocationAuthorization() {
        locationTagger.requestAuthorization()
    }

    func capture(trigger: AlarmTrigger, settings: SettingsStorage) async -> Evidence {
        let wantsPhoto = settings.captureEvidence || settings.pushEnabled
        let wantsLocation = settings.tagLocation

        async let jpeg: Data? = wantsPhoto ? camera.snapshot() : nil
        async let location: CLLocation? = wantsLocation ? locationTagger.currentFix() : nil

        let date = Date()
        let capturedJPEG = await jpeg
        let fix = await location

        // Only persist to disk when the user asked to keep evidence locally.
        let url: URL?
        if settings.captureEvidence {
            let metadata = EvidenceStore.Metadata(
                trigger: trigger.rawValue,
                date: date,
                latitude: fix?.coordinate.latitude,
                longitude: fix?.coordinate.longitude
            )
            url = EvidenceStore.save(jpeg: capturedJPEG, metadata: metadata)
        } else {
            url = nil
        }

        return Evidence(jpegURL: url, jpeg: capturedJPEG, location: fix, trigger: trigger, date: date)
    }

    /// Sends the remote alert when enabled. Best-effort; safe to call regardless of settings.
    func deliver(_ evidence: Evidence, settings: SettingsStorage) async {
        guard settings.pushEnabled else { return }

        let email = settings.ntfyEmail.trimmingCharacters(in: .whitespaces)
        let alert = NotificationSender.Alert(
            title: "LurkAway tamper — \(evidence.trigger.rawValue)",
            message: Self.message(for: evidence),
            jpeg: evidence.jpeg,
            filename: evidence.jpegURL?.lastPathComponent ?? "lurkaway.jpg",
            email: email.isEmpty ? nil : email
        )
        let token = KeychainStore.get(account: KeychainStore.ntfyTokenAccount)
        _ = await sender.send(alert, server: settings.ntfyServer, topic: settings.ntfyTopic, token: token)
    }

    private static func message(for evidence: Evidence) -> String {
        let time = evidence.date.formatted(date: .abbreviated, time: .shortened)
        var lines = ["Tamper detected (\(evidence.trigger.rawValue)) at \(time)."]
        if let fix = evidence.location {
            let lat = fix.coordinate.latitude, lon = fix.coordinate.longitude
            lines.append("Location: https://maps.apple.com/?ll=\(lat),\(lon)")
        }
        return lines.joined(separator: "\n")
    }
}
