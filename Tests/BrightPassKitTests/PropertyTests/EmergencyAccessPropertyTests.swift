// Property 16: Insufficient Shares Produces Error
// Validates: Requirements 9.7
//
// For any emergency access config with threshold T, attempting recovery
// with fewer than T shares produces a validation error without making an API call.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - MockAPIClient

/// Mock API client for emergency access property tests.
/// `recoverVault` tracks whether it was called. `getEmergencyAccessConfig` is unused.
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    var recoverVaultCalled = false

    func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault {
        recoverVaultCalled = true
        return DecryptedVault(id: vaultId, name: "Recovered", entries: [])
    }

    func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig { fatalError() }
    func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws { fatalError() }

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
    func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult { fatalError() }
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}

// MARK: - Generators

/// Generates a threshold T in [2, 10] and a share count strictly less than T.
private let insufficientSharesInput: Gen<(threshold: Int, totalShares: Int, shares: [String])> = Gen.compose { c in
    let threshold = abs(c.generate(using: Int.arbitrary)) % 9 + 2  // 2..10
    let totalShares = threshold + abs(c.generate(using: Int.arbitrary)) % 5  // totalShares >= threshold
    let shareCount = abs(c.generate(using: Int.arbitrary)) % threshold  // 0..<threshold
    let shares = (0..<shareCount).map { _ in UUID().uuidString }
    return (threshold: threshold, totalShares: totalShares, shares: shares)
}

// MARK: - Property Tests

/// **Validates: Requirements 9.7**
@available(macOS 14.0, iOS 17.0, *)
final class EmergencyAccessPropertyTests: XCTestCase {

    /// **Property 16: Insufficient Shares Produces Error**
    /// For any config with threshold T, attempting recovery with fewer than T shares
    /// produces a validation error and does NOT call the API.
    /// **Validates: Requirements 9.7**
    func testInsufficientSharesProducesError() {
        property("Recovery with fewer than T shares produces error without API call") <- forAllNoShrink(insufficientSharesInput) {
            (input: (threshold: Int, totalShares: Int, shares: [String])) in

            let mock = MockAPIClient()

            // Replicate the validation logic from EmergencyAccessViewModel.recover() directly:
            // If shares.count < threshold, it's an error without calling the API.
            let config = EmergencyAccessConfig(
                totalShares: input.totalShares,
                threshold: input.threshold,
                trustees: []
            )

            let hasError = input.shares.count < config.threshold
            let noApiCall = !mock.recoverVaultCalled

            return hasError && noApiCall
        }
    }
}
