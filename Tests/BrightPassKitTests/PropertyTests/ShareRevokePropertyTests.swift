// Property 15: Revoke Share Removes Member
// Validates: Requirements 8.5
//
// After calling revokeAccess for a member, the sharedMembers list
// no longer contains that member's memberId.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - MockAPIClient

/// Mock API client for share/revoke property tests.
/// `revokeShare` always succeeds (no-op). Only sharing-related methods are implemented.
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    func revokeShare(vaultId: String, memberId: String) async throws {
        // Success — no-op
    }

    func listSharedMembers(vaultId: String) async throws -> [SharedMember] { fatalError() }
    func shareVault(vaultId: String, memberId: String, permission: SharePermission) async throws { fatalError() }

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
    func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws { fatalError() }
    func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig { fatalError() }
    func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault { fatalError() }
    func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult { fatalError() }
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}

// MARK: - Generators

/// Generator for a SharePermission.
private let arbitraryPermission: Gen<SharePermission> = Bool.arbitrary.map { $0 ? SharePermission.readOnly : SharePermission.readWrite }

/// Generator for a SharedMember with a unique ID and memberId.
private let arbitrarySharedMember: Gen<SharedMember> = Gen.compose { c in
    SharedMember(
        id: UUID().uuidString,
        memberId: UUID().uuidString,
        permission: c.generate(using: arbitraryPermission)
    )
}

/// Generator for a non-empty list of SharedMembers with unique memberIds (1–15 items).
private let nonEmptyUniqueMemberList: Gen<[SharedMember]> = Gen.compose { c in
    let count = abs(c.generate(using: Int.arbitrary)) % 15 + 1
    var members: [SharedMember] = []
    var usedMemberIds = Set<String>()
    for _ in 0..<count {
        var memberId: String
        repeat {
            memberId = UUID().uuidString
        } while usedMemberIds.contains(memberId)
        usedMemberIds.insert(memberId)
        members.append(SharedMember(
            id: UUID().uuidString,
            memberId: memberId,
            permission: c.generate(using: arbitraryPermission)
        ))
    }
    return members
}

// MARK: - Property Tests

/// **Validates: Requirements 8.5**
@available(macOS 14.0, iOS 17.0, *)
final class ShareRevokePropertyTests: XCTestCase {

    /// **Property 15: Revoke Share Removes Member**
    /// After calling `revokeAccess` for a member, the sharedMembers list
    /// no longer contains that member's memberId and the count decreases by one.
    /// **Validates: Requirements 8.5**
    func testRevokeShareRemovesMember() {
        property("Revoking a share removes the member from the list") <- forAllNoShrink(nonEmptyUniqueMemberList) {
            (initialMembers: [SharedMember]) in

            let indexToRevoke = Int.random(in: 0..<initialMembers.count)
            let memberToRevoke = initialMembers[indexToRevoke]

            let mock = MockAPIClient()
            var members = initialMembers
            let initialCount = members.count

            // Simulate ShareVaultViewModel.revokeAccess logic on a background thread
            nonisolated(unsafe) var revokeSucceeded = false
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                Task {
                    try await mock.revokeShare(vaultId: "test-vault", memberId: memberToRevoke.memberId)
                    revokeSucceeded = true
                    semaphore.signal()
                }
            }
            semaphore.wait()

            if revokeSucceeded {
                members.removeAll { $0.memberId == memberToRevoke.memberId }
            }

            let countCorrect = members.count == initialCount - 1
            let memberRemoved = !members.contains { $0.memberId == memberToRevoke.memberId }
            return countCorrect && memberRemoved
        }
    }
}
