// Property 2: Preservation — Non-Entry-Count Vault Metadata and Operations
//
// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
//
// These tests capture the CURRENT (unfixed) behavior of VaultMetadata decoding
// and VaultListViewModel operations. They are expected to PASS on unfixed code,
// confirming the baseline behavior that must be preserved after the fix.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - ISO8601 Date Helpers

/// Generates a valid ISO8601 date string with fractional seconds.
private let iso8601DateStringGen: Gen<String> = Gen.compose { c in
    let year = abs(c.generate(using: Int.arbitrary)) % 50 + 2000   // 2000–2049
    let month = abs(c.generate(using: Int.arbitrary)) % 12 + 1     // 1–12
    let day = abs(c.generate(using: Int.arbitrary)) % 28 + 1       // 1–28
    let hour = abs(c.generate(using: Int.arbitrary)) % 24           // 0–23
    let minute = abs(c.generate(using: Int.arbitrary)) % 60         // 0–59
    let second = abs(c.generate(using: Int.arbitrary)) % 60         // 0–59
    let frac = abs(c.generate(using: Int.arbitrary)) % 1000         // 0–999
    return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", year, month, day, hour, minute, second, frac)
}

/// Generates an optional ISO8601 date string (50% nil).
private let optionalISO8601Gen: Gen<String?> = Gen<String?>.one(of: [
    iso8601DateStringGen.map { Optional($0) },
    Gen.pure(nil)
])

/// Generates an optional non-empty string.
private let optionalStringGen: Gen<String?> = Gen<String?>.one(of: [
    String.arbitrary.suchThat { !$0.isEmpty }.map { Optional($0) },
    Gen.pure(nil)
])

/// Generates an optional [String] array.
private let optionalStringArrayGen: Gen<[String]?> = Gen<[String]?>.one(of: [
    String.arbitrary.suchThat { !$0.isEmpty }.proliferate.map { Optional(Array($0.prefix(5))) },
    Gen.pure(nil)
])

// MARK: - Mock API Client for Vault Operations

/// Mock conforming to `APIClientProtocol` for preservation tests.
/// Supports listVaults, createVault, and deleteVault.
@available(macOS 14.0, iOS 17.0, *)
private final class PreservationMockAPIClient: APIClientProtocol, @unchecked Sendable {

    var vaultsToReturn: [VaultMetadata] = []

    func listVaults() async throws -> [VaultMetadata] {
        return vaultsToReturn
    }

    func createVault(name: String, masterPassword: String) async throws -> VaultMetadata {
        VaultMetadata(
            id: UUID().uuidString,
            name: name,
            ownerId: "owner-test",
            createdAt: "2024-01-01T00:00:00.000Z"
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

// MARK: - Property Tests

@available(macOS 14.0, iOS 17.0, *)
final class VaultMetadataPreservationPropertyTests: XCTestCase {

    // MARK: - Property 2a: VaultMetadata JSON field decoding preserves all non-entryCount fields

    /// For all random VaultMetadata JSON payloads, id, name, ownerId, createdAt, updatedAt,
    /// sharedWith, and vcblBlockId decode to the expected values.
    /// **Validates: Requirements 3.2, 3.4**
    func testVaultMetadataFieldDecodingPreservation() {
        property("VaultMetadata non-entryCount fields decode correctly from JSON") <- forAll(
            String.arbitrary.suchThat { !$0.isEmpty },
            String.arbitrary.suchThat { !$0.isEmpty },
            optionalStringGen,
            optionalISO8601Gen,
            optionalISO8601Gen,
            optionalStringArrayGen,
            optionalStringGen
        ) { (id: String, name: String, ownerId: String?, createdAt: String?, updatedAt: String?, sharedWith: [String]?, vcblBlockId: String?) in

            // Build JSON manually to control exact field values
            var jsonDict: [String: Any] = [
                "id": id,
                "name": name
            ]
            if let ownerId = ownerId { jsonDict["ownerId"] = ownerId }
            if let createdAt = createdAt { jsonDict["createdAt"] = createdAt }
            if let updatedAt = updatedAt { jsonDict["updatedAt"] = updatedAt }
            if let sharedWith = sharedWith { jsonDict["sharedWith"] = sharedWith }
            if let vcblBlockId = vcblBlockId { jsonDict["vcblBlockId"] = vcblBlockId }
            // Include entryCount to verify it is silently ignored after the fix
            jsonDict["entryCount"] = 42

            guard let data = try? JSONSerialization.data(withJSONObject: jsonDict),
                  let decoded = try? JSONDecoder().decode(VaultMetadata.self, from: data) else {
                return false
            }

            return decoded.id == id
                && decoded.name == name
                && decoded.ownerId == ownerId
                && decoded.createdAt == createdAt
                && decoded.updatedAt == updatedAt
                && decoded.sharedWith == sharedWith
                && decoded.vcblBlockId == vcblBlockId
        }
    }

    // MARK: - Property 2b: lastModified returns parsed updatedAt date

    /// For all VaultMetadata with valid ISO8601 updatedAt, lastModified returns the parsed date.
    /// **Validates: Requirements 3.2**
    func testLastModifiedReturnsUpdatedAtDate() {
        property("lastModified returns parsed updatedAt when present") <- forAll(
            iso8601DateStringGen
        ) { (updatedAt: String) in
            let vault = VaultMetadata(
                id: "test-id",
                name: "Test",
                ownerId: nil,
                createdAt: "2020-01-01T00:00:00.000Z",
                updatedAt: updatedAt
            )

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let expectedDate = formatter.date(from: updatedAt) else {
                return false
            }

            return vault.lastModified == expectedDate
        }
    }

    // MARK: - Property 2c: lastModified falls back to createdAt when updatedAt is nil

    /// For all VaultMetadata with nil updatedAt but valid createdAt, lastModified falls back to createdAt.
    /// **Validates: Requirements 3.2**
    func testLastModifiedFallsBackToCreatedAt() {
        property("lastModified falls back to createdAt when updatedAt is nil") <- forAll(
            iso8601DateStringGen
        ) { (createdAt: String) in
            let vault = VaultMetadata(
                id: "test-id",
                name: "Test",
                ownerId: nil,
                createdAt: createdAt,
                updatedAt: nil
            )

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let expectedDate = formatter.date(from: createdAt) else {
                return false
            }

            return vault.lastModified == expectedDate
        }
    }

    // MARK: - Property 2d: loadVaults populates vaults array with correct metadata

    /// VaultListViewModel.loadVaults() populates vaults array with correct metadata.
    /// Uses @MainActor manual iteration to avoid deadlocks.
    /// **Validates: Requirements 3.1, 3.2**
    @MainActor
    func testLoadVaultsPopulatesCorrectMetadata() async {
        for _ in 0..<50 {
            let mock = PreservationMockAPIClient()
            let vaultCount = Int.random(in: 0...10)
            var expectedVaults: [VaultMetadata] = []
            for i in 0..<vaultCount {
                expectedVaults.append(VaultMetadata(
                    id: "vault-\(i)-\(UUID().uuidString)",
                    name: "Vault \(i)",
                    ownerId: "owner-\(i)",
                    createdAt: "2024-01-0\(min(i + 1, 9))T00:00:00.000Z"
                ))
            }
            mock.vaultsToReturn = expectedVaults

            let vm = VaultListViewModel(apiClient: mock)
            await vm.loadVaults()

            XCTAssertEqual(vm.vaults.count, expectedVaults.count)
            for (actual, expected) in zip(vm.vaults, expectedVaults) {
                XCTAssertEqual(actual.id, expected.id)
                XCTAssertEqual(actual.name, expected.name)
                XCTAssertEqual(actual.ownerId, expected.ownerId)
                XCTAssertEqual(actual.createdAt, expected.createdAt)
            }
            XCTAssertFalse(vm.isLoading)
            XCTAssertNil(vm.error)
        }
    }

    // MARK: - Property 2e: createVault appends new vault to list

    /// VaultListViewModel.createVault() appends new vault to list.
    /// Uses @MainActor manual iteration to avoid deadlocks.
    /// **Validates: Requirements 3.5**
    @MainActor
    func testCreateVaultAppendsToList() async {
        for _ in 0..<50 {
            let mock = PreservationMockAPIClient()
            let initialCount = Int.random(in: 0...5)
            var initialVaults: [VaultMetadata] = []
            for i in 0..<initialCount {
                initialVaults.append(VaultMetadata(
                    id: "existing-\(i)",
                    name: "Existing \(i)"
                ))
            }
            mock.vaultsToReturn = initialVaults

            let vm = VaultListViewModel(apiClient: mock)
            vm.vaults = initialVaults

            let newName = "New Vault \(UUID().uuidString.prefix(8))"
            await vm.createVault(name: newName, masterPassword: "password123")

            XCTAssertEqual(vm.vaults.count, initialCount + 1)
            XCTAssertEqual(vm.vaults.last?.name, newName)
            XCTAssertFalse(vm.isLoading)
            XCTAssertNil(vm.error)
        }
    }

    // MARK: - Property 2f: deleteVault removes vault from list

    /// VaultListViewModel.deleteVault() removes vault from list.
    /// Uses @MainActor manual iteration to avoid deadlocks.
    /// **Validates: Requirements 3.3**
    @MainActor
    func testDeleteVaultRemovesFromList() async {
        for _ in 0..<50 {
            let mock = PreservationMockAPIClient()
            let vaultCount = Int.random(in: 1...10)
            var vaults: [VaultMetadata] = []
            for i in 0..<vaultCount {
                vaults.append(VaultMetadata(
                    id: "vault-\(i)",
                    name: "Vault \(i)"
                ))
            }

            let vm = VaultListViewModel(apiClient: mock)
            vm.vaults = vaults

            let indexToDelete = Int.random(in: 0..<vaultCount)
            let vaultToDelete = vaults[indexToDelete]

            await vm.deleteVault(vaultToDelete)

            XCTAssertEqual(vm.vaults.count, vaultCount - 1)
            XCTAssertFalse(vm.vaults.contains { $0.id == vaultToDelete.id })
            XCTAssertFalse(vm.isLoading)
            XCTAssertNil(vm.error)
        }
    }
}
