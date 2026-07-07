import Testing
import Foundation
@testable import LurkAway

/// Focused tests on the two pieces with real, silent bug surface: the ntfy request builder
/// (including the header-injection guard) and the walk-away seconds→cycles math. Everything
/// else in this feature is side-effectful (camera/location/network/UI) and covered by manual E2E.

@Suite("ntfy request builder")
struct NotificationSenderTests {
    private func alert(title: String = "t", message: String = "m", jpeg: Data? = nil, email: String? = nil) -> NotificationSender.Alert {
        NotificationSender.Alert(title: title, message: message, jpeg: jpeg, filename: "e.jpg", email: email)
    }

    @Test("Builds POST to server/topic with core headers")
    func buildsRequest() throws {
        let req = try #require(NotificationSender.makeRequest(alert(), server: "https://ntfy.sh", topic: "abc", token: nil))
        #expect(req.url?.absoluteString == "https://ntfy.sh/abc")
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "Title") == "t")
        #expect(req.value(forHTTPHeaderField: "Priority") == "urgent")
        #expect(req.value(forHTTPHeaderField: "Message") == "m")
    }

    @Test("Rejects empty topic and non-http(s) server")
    func rejectsInvalid() {
        #expect(NotificationSender.makeRequest(alert(), server: "https://ntfy.sh", topic: "   ", token: nil) == nil)
        #expect(NotificationSender.makeRequest(alert(), server: "ftp://x", topic: "abc", token: nil) == nil)
        #expect(NotificationSender.makeRequest(alert(), server: "", topic: "abc", token: nil) == nil)
    }

    @Test("Strips CR/LF so text can't inject extra headers")
    func headerInjectionStripped() throws {
        let evil = "hi\r\nTags: skull\r\nPriority: min"
        let req = try #require(NotificationSender.makeRequest(alert(title: evil, message: evil), server: "https://ntfy.sh", topic: "abc", token: nil))
        let title = req.value(forHTTPHeaderField: "Title") ?? ""
        #expect(!title.contains("\n"))
        #expect(!title.contains("\r"))
    }

    @Test("Email header only for a valid address")
    func emailHeaderGating() throws {
        let ok = try #require(NotificationSender.makeRequest(alert(email: "a@b.com"), server: "https://ntfy.sh", topic: "abc", token: nil))
        #expect(ok.value(forHTTPHeaderField: "Email") == "a@b.com")

        let bad = try #require(NotificationSender.makeRequest(alert(email: "not-an-email"), server: "https://ntfy.sh", topic: "abc", token: nil))
        #expect(bad.value(forHTTPHeaderField: "Email") == nil)
    }

    @Test("Bearer token and Filename appear only when supplied")
    func tokenAndAttachment() throws {
        let withToken = try #require(NotificationSender.makeRequest(alert(), server: "https://ntfy.sh", topic: "abc", token: "secret"))
        #expect(withToken.value(forHTTPHeaderField: "Authorization") == "Bearer secret")

        let noJPEG = try #require(NotificationSender.makeRequest(alert(message: "hello"), server: "https://ntfy.sh", topic: "abc", token: nil))
        #expect(noJPEG.value(forHTTPHeaderField: "Filename") == nil)
        #expect(noJPEG.httpBody == "hello".data(using: .utf8))

        let withJPEG = try #require(NotificationSender.makeRequest(alert(jpeg: Data([0xFF, 0xD8])), server: "https://ntfy.sh", topic: "abc", token: nil))
        #expect(withJPEG.value(forHTTPHeaderField: "Filename") == "e.jpg")
        #expect(withJPEG.httpBody == Data([0xFF, 0xD8]))
    }

    @Test("Email validation", arguments: [
        ("a@b.com", true), ("x.y@z.co.uk", true),
        ("no-at", false), ("a@b", false), ("a b@c.com", false), ("", false),
    ])
    func emailValidation(email: String, expected: Bool) {
        #expect(NotificationSender.isValidEmail(email) == expected)
    }
}

@Suite("walk-away delay mapping")
@MainActor
struct WalkAwayThresholdTests {
    @Test("5s default maps to 3 cycles (v1 behavior)")
    func defaultMapping() {
        let s = SettingsStorage()
        s.walkAwayDelaySeconds = 5.0
        #expect(s.noFaceThreshold == 3)
    }

    @Test("Seconds convert to rounded 1.5s cycles, floored at 1", arguments: [
        (2.0, 1), (15.0, 10), (0.5, 1), (3.0, 2), (6.0, 4),
    ])
    func mapping(seconds: Double, cycles: Int) {
        let s = SettingsStorage()
        s.walkAwayDelaySeconds = seconds
        #expect(s.noFaceThreshold == cycles)
    }
}
