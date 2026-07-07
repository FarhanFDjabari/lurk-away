import Foundation
import CoreLocation
import os

/// Owns the on-disk evidence folder: writing tamper snapshots, counting them, and — importantly —
/// deleting them. Kept `nonisolated` so both the alarm path and the Settings UI can use it.
enum EvidenceStore {
    struct Metadata: Codable {
        let trigger: String
        let date: Date
        let latitude: Double?
        let longitude: Double?
    }

    /// ~/Library/Application Support/LurkAway/Evidence
    static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("LurkAway/Evidence", isDirectory: true)
    }

    /// Writes `<timestamp>.jpg` plus a `<timestamp>.json` sidecar. Returns the image URL,
    /// or nil on failure. Never throws — the alarm path must not be interrupted.
    @discardableResult
    static func save(jpeg: Data?, metadata: Metadata) -> URL? {
        guard let jpeg else { return nil }
        do {
            let dir = directoryURL
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let stamp = timestamp(metadata.date)
            let imageURL = dir.appendingPathComponent("\(stamp).jpg")
            try jpeg.write(to: imageURL, options: .atomic)
            if let json = try? JSONEncoder().encode(metadata) {
                try? json.write(to: dir.appendingPathComponent("\(stamp).json"), options: .atomic)
            }
            log.notice("Evidence saved: \(imageURL.lastPathComponent, privacy: .private)")
            return imageURL
        } catch {
            log.error("Evidence save failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Number of stored evidence images.
    static func itemCount() -> Int {
        let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: nil
        )
        return urls?.filter { $0.pathExtension == "jpg" }.count ?? 0
    }

    /// Deletes every stored image and sidecar by removing the folder. Throws so the UI can report.
    static func clearAll() throws {
        let dir = directoryURL
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        try FileManager.default.removeItem(at: dir)
        log.notice("All evidence cleared")
    }

    /// Filesystem-safe ISO8601 (no colons) so files sort chronologically.
    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
        return formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
    }
}
