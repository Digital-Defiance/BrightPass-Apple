// Property 32: Vault Rename Optimistic Update
// Validates: Requirements 23.4
//
// After a successful rename, the vault's name in VaultListViewModel.vaults
// equals the new name and the array count is unchanged.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Mock APIClient

@available(macOS 14.0, iOS 17.0, *)
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    func renameVault(id: String, name: String) async throws -> VaultMetadata {
        VaultMetadata(id: id, name: name)
    }

    func listVaults() async throws -> [VaultMetadata] { [] }

    // MARK: - Unused stubs
    func requestDirectLogin() async throws -> DirectLoginChallenge { fatalError() }
    func submitDirectChallenge(challenge: String, signature: String, username: String?, email: String?) async throws -> DirectChallengeResponse { fatalError() }
    func refreshToken() async throws -> DirectChallengeResponse { fatalError() }
    func logout() async throws { fatalError() }
    func verifyToken() async throws -> UserProfile { fatalError() }
    func login(username: String, password: String) async throws -> AuthResponse { fatalError() }
    func register(username: String, email: String, password: String) async throws -> AuthResponse { fatalError() }
    func createVault(name: String, masterPassword: String) async throws -> VaultMetadata { fatalError() }
    func openVault(id: String, masterPassword: String) async throws -> DecryptedVault { fatalError() }
    func deleteVault(id: String) async throws { fatalError() }
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
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}

// MARK: - Property Tests

/// **Property 32: Vault Rename Optimistic Update**
/// **Validates: Requirements 23.4**
@available(macOS 14.0, iOS 17.0, *)
final class VaultRenameOptimisticPropertyTests: XCTestCase {

    /// After a successful rename, the vault's name in VaultListViewModel.vaults
    /// equals the new name and the array count is unchanged.
    @MainActor
    func testRenameUpdatesNameAndPreservesCount() {
        for _ in 0..<200 {
            let newName = String.arbitrary.generate
            let mock = MockAPIClient()
            let keychain = MockKeychainStore()

            // Build a random vault list with 1–10 vaults
            let count = Int.random(in: 1...10)
            var vaults: [VaultMetadata] = []
            for _ in 0..<count {
                vaults.append(VaultMetadata(
                    id: UUID().uuidString,
                    name: String.arbitrary.generate
                ))
            }

            let targetIndex = Int.random(in: 0..<count)
            let targetVaultId = vaults[targetIndex].id

            let listVM = VaultListViewModel(apiClient: mock)
            listVM.vaults = vaults
            let initialCount = listVM.vaults.count

            let renameVM = VaultRenameViewModel(apiClient: mock)
            renameVM.newName = newName

            let expectation = XCTestExpectation(description: "rename completes")
            Task { @MainActor in
                await renameVM.renameVault(vaultId: targetVaultId, vaultListViewModel: listVM)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2.0)

            XCTAssertNil(renameVM.error, "Rename should succeed")
            XCTAssertEqual(listVM.vaults.count, initialCount, "Vault count should be unchanged after rename")

            let renamedVault = listVM.vaults.first(where: { $0.id == targetVaultId })
            XCTAssertEqual(renamedVault?.name, newName, "Vault name should be updated to '\(newName)'")
        }
    }
}
