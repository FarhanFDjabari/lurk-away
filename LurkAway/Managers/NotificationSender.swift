import Foundation
import os

/// Posts a tamper alert to an ntfy server. One request drives both delivery modes:
/// topic subscribers (ntfy app or the topic URL in a browser) get the photo inline; if an
/// email is set, ntfy also forwards a text-only email. No account or server setup required
/// for the hosted ntfy.sh. Best-effort: the siren is the primary deterrent.
struct NotificationSender {
    struct Alert {
        let title: String
        let message: String
        let jpeg: Data?
        let filename: String
        let email: String?
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Returns true on a 2xx response. Never throws; logs failures.
    func send(_ alert: Alert, server: String, topic: String, token: String?) async -> Bool {
        guard let request = Self.makeRequest(alert, server: server, topic: topic, token: token) else {
            log.error("ntfy send skipped — invalid server/topic")
            return false
        }
        do {
            let (_, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let ok = (200..<300).contains(code)
            if !ok { log.error("ntfy send failed — HTTP \(code, privacy: .public)") }
            return ok
        } catch {
            log.error("ntfy send error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Builds the ntfy request. Exposed for testing (no network). Returns nil on invalid input.
    static func makeRequest(_ alert: Alert, server: String, topic: String, token: String?) -> URLRequest? {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespaces)
        let trimmedServer = server.trimmingCharacters(in: .whitespaces)
        guard !trimmedTopic.isEmpty,
              let base = URL(string: trimmedServer),
              base.scheme == "https" || base.scheme == "http" else {
            return nil
        }

        var request = URLRequest(url: base.appendingPathComponent(trimmedTopic))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue(headerSafe(alert.title), forHTTPHeaderField: "Title")
        request.setValue("urgent", forHTTPHeaderField: "Priority")
        request.setValue("rotating_light", forHTTPHeaderField: "Tags")
        request.setValue(headerSafe(alert.message), forHTTPHeaderField: "Message")

        if let email = alert.email, isValidEmail(email) {
            request.setValue(headerSafe(email), forHTTPHeaderField: "Email")
        }
        if let token, !token.isEmpty {
            request.setValue("Bearer \(headerSafe(token))", forHTTPHeaderField: "Authorization")
        }

        if let jpeg = alert.jpeg, !jpeg.isEmpty {
            request.setValue(headerSafe(alert.filename), forHTTPHeaderField: "Filename")
            request.httpBody = jpeg
        } else {
            request.httpBody = alert.message.data(using: .utf8)
        }
        return request
    }

    /// Strips CR/LF so caller-supplied text can't inject extra headers.
    private static func headerSafe(_ value: String) -> String {
        value.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
    }

    static func isValidEmail(_ email: String) -> Bool {
        email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}
