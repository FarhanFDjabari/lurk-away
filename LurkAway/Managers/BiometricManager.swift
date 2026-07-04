import LocalAuthentication

@MainActor
final class BiometricManager {
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("[LurkAway] Biometric auth not available: \(error?.localizedDescription ?? "unknown")")
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            print("[LurkAway] Authentication failed: \(error.localizedDescription)")
            return false
        }
    }
}
