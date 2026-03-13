// Property 30: Password Change Confirmation Mismatch Validation
// Validates: Requirements 22.6
//
// For any two non-equal password strings as new password and confirmation,
// the view model sets a validation error without making an API call.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Mock APIClient (tracks calls)

@available(macOS 14.0, iOS 17.0, *)
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    var changeMasterPasswordCalled = false

    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws {
        changeMasterPasswordCalled = true
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

/// **Property 30: Password Change Confirmation Mismatch Validation**
/// **Validates: Requirements 22.6**
@available(macOS 14.0, iOS 17.0, *)
final class PasswordChangeMismatchPropertyTests: XCTestCase {

    /// For any two non-equal password strings, the view model sets a validation error
    /// without making an API call.
    @MainActor
    func testMismatchedConfirmationSetsErrorWithoutAPICall() {
        // Generate pairs of non-equal strings and verify behavior
        let pairGen = Gen.zip(String.arbitrary, String.arbitrary).suchThat { $0.0 != $0.1 }

        for _ in 0..<200 {
            let (newPwd, confirmPwd) = pairGen.generate
            let mock = MockAPIClient()
            let keychain = MockKeychainStore()
            let vm = MasterPasswordChangeViewModel(apiClient: mock, keychainStore: keychain)

            vm.currentPassword = "current123"
            vm.newPassword = newPwd
            vm.confirmNewPassword = confirmPwd

            // Run synchronously — changePassword returns early on mismatch (no async API call)
            let expectation = XCTestExpectation(description: "changePassword completes")
            Task { @MainActor in
                await vm.changePassword(vaultId: "vault-1")
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2.0)

            XCTAssertNotNil(vm.error, "Error should be set for mismatched passwords: '\(newPwd)' vs '\(confirmPwd)'")
            XCTAssertFalse(mock.changeMasterPasswordCalled, "API should not be called when passwords don't match")
            XCTAssertFalse(vm.isSuccess, "isSuccess should remain false on mismatch")
        }
    }
}
