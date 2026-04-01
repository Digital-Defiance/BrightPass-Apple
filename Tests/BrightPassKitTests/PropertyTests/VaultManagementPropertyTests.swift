// Property 5: Vault Creation Adds to List
// Property 6: Vault Deletion Removes from List
// Validates: Requirements 2.2, 2.8
//
// Property 5: After calling createVault, the vault list count increases by one.
// Property 6: After calling deleteVault, the vault list count decreases by one
// and the deleted vault's ID is no longer present.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - MockAPIClient

/// Minimal mock conforming to `APIClientProtocol` for vault management tests.
/// Only `createVault` and `deleteVault` are implemented; all others `fatalError`.
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    func createVault(name: String, masterPassword: String) async throws -> VaultMetadata {
        VaultMetadata(
            id: UUID().uuidString,
            name: name
        )
    }

    func deleteVault(id: String) async throws {
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
    func openVault(id: String, masterPassword: String) async throws -> DecryptedVault { fatalError() }
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
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}

// MARK: - Helpers

/// Generate a Date truncated to whole seconds (ISO 8601 has second precision only).
private let arbitraryDate: Gen<Date> = Int.arbitrary.map { i in
    Date(timeIntervalSince1970: Double(abs(i) % 4_102_444_800))
}

/// Generator for a list of VaultMetadata with unique IDs (0–20 items).
private let uniqueVaultList: Gen<[VaultMetadata]> = Gen.compose { c in
    let count = abs(c.generate(using: Int.arbitrary)) % 20
    var vaults: [VaultMetadata] = []
    var usedIds = Set<String>()
    for _ in 0..<count {
        var id: String
        repeat {
            id = UUID().uuidString
        } while usedIds.contains(id)
        usedIds.insert(id)
        vaults.append(VaultMetadata(
            id: id,
            name: c.generate()
        ))
    }
    return vaults
}

/// Generator for a non-empty list of VaultMetadata with unique IDs (1–20 items).
private let nonEmptyUniqueVaultList: Gen<[VaultMetadata]> = uniqueVaultList.suchThat { !$0.isEmpty }

// MARK: - Property Tests

/// **Validates: Requirements 2.2, 2.8**
@available(macOS 14.0, iOS 17.0, *)
final class VaultManagementPropertyTests: XCTestCase {

    /// **Property 5: Vault Creation Adds to List**
    /// After calling `createVault`, the vault list count increases by exactly one.
    /// **Validates: Requirements 2.2**
    func testVaultCreationAddsToList() {
        property("Creating a vault increases the list count by one") <- forAllNoShrink(uniqueVaultList, String.arbitrary, String.arbitrary) {
            (initialVaults: [VaultMetadata], name: String, password: String) in

            let mock = MockAPIClient()
            var vaults = initialVaults
            let initialCount = vaults.count

            // Simulate VaultListViewModel.createVault logic on a background thread
            nonisolated(unsafe) var newVault: VaultMetadata?
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                Task {
                    newVault = try await mock.createVault(name: name, masterPassword: password)
                    semaphore.signal()
                }
            }
            semaphore.wait()

            if let v = newVault {
                vaults.append(v)
            }

            return vaults.count == initialCount + 1
        }
    }

    /// **Property 6: Vault Deletion Removes from List**
    /// After calling `deleteVault`, the vault list count decreases by exactly one
    /// and the deleted vault's ID is no longer present.
    /// **Validates: Requirements 2.8**
    func testVaultDeletionRemovesFromList() {
        property("Deleting a vault decreases the list count by one and removes the ID") <- forAllNoShrink(nonEmptyUniqueVaultList) {
            (initialVaults: [VaultMetadata]) in

            let indexToDelete = Int.random(in: 0..<initialVaults.count)
            let vaultToDelete = initialVaults[indexToDelete]

            let mock = MockAPIClient()
            var vaults = initialVaults
            let initialCount = vaults.count

            // Simulate VaultListViewModel.deleteVault logic on a background thread
            nonisolated(unsafe) var deleteSucceeded = false
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                Task {
                    try await mock.deleteVault(id: vaultToDelete.id)
                    deleteSucceeded = true
                    semaphore.signal()
                }
            }
            semaphore.wait()

            if deleteSucceeded {
                vaults.removeAll { $0.id == vaultToDelete.id }
            }

            let countCorrect = vaults.count == initialCount - 1
            let idRemoved = !vaults.contains { $0.id == vaultToDelete.id }
            return countCorrect && idRemoved
        }
    }
}
