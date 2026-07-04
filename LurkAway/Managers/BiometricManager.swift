import LocalAuthentication

@MainActor
final class BiometricManager {
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        // Show a clear "Enter Password" fallback the moment Touch ID fails or is unavailable.
        context.localizedFallbackTitle = "Enter Password"

        var error: NSError?
        // .deviceOwnerAuthentication = Touch ID OR the device password/passcode, so this
        // still works when Touch ID is locked out, unenrolled, or absent.
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            } catch {
                print("[LurkAway] Authentication failed: \(error.localizedDescription)")
                return false
            }
        }

        print("[LurkAway] Device authentication unavailable: \(error?.localizedDescription ?? "unknown")")
        return false
    }
}
