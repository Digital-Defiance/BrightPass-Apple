// Property 31: Biometric Hash Update After Password Change
// Validates: Requirements 22.4
//
// For a vault with biometric enabled, after a successful password change,
// the hash in KeychainStore corresponds to the new password.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Mock APIClient (succeeds on changeMasterPassword)

@available(macOS 14.0, iOS 17.0, *)
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws {
        // Success — no-op
    }

    // MARK: - Unused stubs
    func requestDirectLogin() async throws -> DirectLoginChallenge { fatalError() }
    func submitDirectChallenge(challenge: String, signature: String, username: String?, email: String?) async throws -> DirectChallengeResponse { fatalError() }
    func refreshToken() async throws -> DirectChallengeResponse { fatalError() }
    func logout() async throws { fatalError() }
    func verifyToken() async throws -> UserProfile { fatalError() }
    func login(username: String, password: String) async throws -> AuthResponse { fatalError() }
    func register(username: String, email: String, password: String) async throws -> AuthResponse { fatalError() }
    func listVaults() async throws -> [VaultMetadata] { fatalError() }
    func createVault(name: String, masterPassword: String) async throws -> VaultMetadata { fatalError() }
    func openVault(id: String, masterPassword: String) async throws -> DecryptedVault { fatalError() }
    func deleteVault(id: String) async throws { fatalError() }
    func renameVault(id: String, name: String) async throws -> VaultMetadata { fatalError() }
    func listEntries(vaultId: String) async throws -> [EntryPropertyRecord] { fatalError() }
    func getEntry(vaultId: String, entryId: String) async throws -> VaultEntry { fatalError() }
    func createEntry(vaultId: String, entry: VaultEntry) async throws -> VaultEntry { fatalError() }
    func updateEntry(vaultId: String, entryId: String, entry: VaultEntry) async throws -> VaultEntry { fatalError() }
    func deleteEntry(vaultId: String, entryId: String) async throws { fatalError() }
    func searchEntries(vaultId: String, query: String) async throws -> [EntryPropertyRecord] { fatalError() }
    func generatePassword(options: PasswordOptions) async throws -> GeneratedPassword { fatalError() }
    func generateTOTP(secret: String) async throws -> TotpCode { fatalError() }
    func validateTOTPSecret(secret: String) async throws -> TotpCode { fatalError() }
    func checkBreach(password: String) async throws -> BreachCheckResult { fatalError() }
    func autofillLookup(serviceIdentifier: String) async throws -> [AutofillPayload] { fatalError() }
    func getAuditLog(vaultId: String) async throws -> [AuditLogEntry] { fatalError() }
    func shareVault(vaultId: String, memberId: String, permission: SharePermission) async throws { fatalError() }
    func revokeShare(vaultId: String, memberId: String) async throws { fatalError() }
    func listSharedMembers(vaultId: String) async throws -> [SharedMember] { fatalError() }
    func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws { fatalError() }
    func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig { fatalError() }
    func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault { fatalError() }
    func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}

// MARK: - Property Tests

/// **Property 31: Biometric Hash Update After Password Change**
/// **Validates: Requirements 22.4**
@available(macOS 14.0, iOS 17.0, *)
final class BiometricHashUpdatePropertyTests: XCTestCase {

    /// For a vault with biometric enabled, after a successful password change,
    /// the hash stored in KeychainStore equals the new password.
    @MainActor
    func testBiometricHashUpdatedAfterPasswordChange() {
        let vaultId = "vault-bio-test"

        for _ in 0..<200 {
            let currentPwd = String.arbitrary.generate
            let newPwd = String.arbitrary.generate

            let mock = MockAPIClient()
            let keychain = MockKeychainStore()

            // Pre-condition: biometric is enabled with the old hash
            try! keychain.saveMasterPasswordHash(currentPwd, vaultId: vaultId, biometricProtected: true)

            let vm = MasterPasswordChangeViewModel(apiClient: mock, keychainStore: keychain)
            vm.currentPassword = currentPwd
            vm.newPassword = newPwd
            vm.confirmNewPassword = newPwd  // matching confirmation

            let expectation = XCTestExpectation(description: "changePassword completes")
            Task { @MainActor in
                await vm.changePassword(vaultId: vaultId)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2.0)

            XCTAssertTrue(vm.isSuccess, "Password change should succeed")

            // The stored hash should now be the new password
            let storedHash = try! keychain.loadMasterPasswordHash(vaultId: vaultId)
            XCTAssertEqual(storedHash, newPwd, "Biometric hash should be updated to the new password")

            // Biometric flag should still be enabled
            let stillBiometric = try! keychain.hasBiometricProtectedHash(vaultId: vaultId)
            XCTAssertTrue(stillBiometric, "Biometric should remain enabled after password change")
        }
    }
}
