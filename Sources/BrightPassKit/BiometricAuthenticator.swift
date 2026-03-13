import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Abstraction over biometric authentication for testability.
/// The concrete implementation wraps `LAContext`; tests can substitute a mock.
public protocol BiometricAuthenticatorProtocol: Sendable {
    /// Whether biometric authentication is available on this device.
    func canEvaluateBiometrics() -> Bool
    /// Evaluate biometric policy. Returns `true` on success, `false` on failure/cancel.
    func evaluateBiometrics(reason: String) async -> Bool
}

#if canImport(LocalAuthentication)
/// Production implementation using `LAContext.evaluatePolicy`.
public final class BiometricAuthenticator: BiometricAuthenticatorProtocol, @unchecked Sendable {
    public init() {}

    public func canEvaluateBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public func evaluateBiometrics(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
#endif
