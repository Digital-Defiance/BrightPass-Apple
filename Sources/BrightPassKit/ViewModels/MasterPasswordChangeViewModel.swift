import Foundation

/// Manages the master password change flow for a vault.
/// Validates confirmation match locally before sending the API request.
/// On success with biometric enabled, updates the stored hash in the Keychain.
///
/// **Validates: Requirements 22.1, 22.2, 22.3, 22.4, 22.5, 22.6**
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class MasterPasswordChangeViewModel {

    public var currentPassword: String = ""
    public var newPassword: String = ""
    public var confirmNewPassword: String = ""
    public var isLoading: Bool = false
    public var error: AppError?
    public var isSuccess: Bool = false

    private let apiClient: APIClientProtocol
    private let keychainStore: KeychainStoreProtocol

    public init(apiClient: APIClientProtocol, keychainStore: KeychainStoreProtocol) {
        self.apiClient = apiClient
        self.keychainStore = keychainStore
    }

    /// Changes the master password for the given vault.
    /// If `newPassword` and `confirmNewPassword` don't match, sets a validation error
    /// without making an API call (Requirement 22.6).
    /// On success with biometric enabled, updates the stored hash (Requirement 22.4).
    public func changePassword(vaultId: String) async {
        error = nil
        isSuccess = false

        // Local validation — no API call if mismatch
        guard newPassword == confirmNewPassword else {
            error = .validationError(messages: ["New password and confirmation do not match."])
            return
        }

        isLoading = true
        do {
            try await apiClient.changeMasterPassword(
                vaultId: vaultId,
                currentPassword: currentPassword,
                newPassword: newPassword
            )

            // Update biometric hash if enabled for this vault
            if let hasBiometric = try? keychainStore.hasBiometricProtectedHash(vaultId: vaultId),
               hasBiometric {
                try? keychainStore.saveMasterPasswordHash(newPassword, vaultId: vaultId, biometricProtected: true)
            }

            isSuccess = true
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }
}
