// Property 19: Lock Clears All Decrypted Data
// Validates: Requirements 12.1, 12.6
//
// For any VaultDetailViewModel populated with a non-nil vault, non-empty entries,
// a non-empty search query, a type filter, and favoritesOnly enabled,
// calling lockVault() SHALL set vault to nil, entries to empty, searchQuery to "",
// typeFilter to nil, and favoritesOnly to false.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Generators

private let arbitraryEntryType: Gen<EntryType> = Gen<Int>.fromElements(in: 0...3).map {
    EntryType.allCases[$0]
}

private let shortAlphaString: Gen<String> = Gen<Character>.fromElements(in: "a"..."z")
    .proliferate(withSize: 10)
    .suchThat { !$0.isEmpty }
    .map { String($0.prefix(max(1, Int.random(in: 1...10)))) }

private let arbitraryEntry: Gen<EntryPropertyRecord> = Gen.compose { c in
    EntryPropertyRecord(
        id: UUID().uuidString,
        title: c.generate(using: shortAlphaString),
        type: c.generate(using: arbitraryEntryType),
        tags: (0..<Int.random(in: 0...3)).map { _ in c.generate(using: shortAlphaString) },
        url: Bool.random() ? "https://\(c.generate(using: shortAlphaString)).com" : nil,
        isFavorite: c.generate()
    )
}

/// Non-empty entry list (1–15 items) so the VM always has data before lock.
private let nonEmptyEntryList: Gen<[EntryPropertyRecord]> = Gen.compose { c in
    let count = max(1, abs(c.generate(using: Int.arbitrary)) % 15)
    return (0..<count).map { _ in c.generate(using: arbitraryEntry) }
}

// MARK: - Property Tests

/// **Validates: Requirements 12.1, 12.6**
@available(macOS 14.0, iOS 17.0, *)
final class LockClearsDataPropertyTests: XCTestCase {

    /// **Property 19: Lock Clears All Decrypted Data**
    /// After populating the view model with arbitrary vault data, entries, search query,
    /// type filter, and favorites flag, calling `lockVault()` clears everything.
    ///
    /// Uses manual random generation to avoid MainActor deadlock with SwiftCheck + semaphore.
    @MainActor
    func testLockClearsAllDecryptedData() {
        let mock = MockKeychainStore()
        let apiClient = StubAPIClient()

        // Run 200 random iterations manually (equivalent to SwiftCheck's default)
        for _ in 0..<200 {
            let entries = nonEmptyEntryList.generate
            let vaultName = shortAlphaString.generate
            let query = shortAlphaString.generate
            let typeFilter = arbitraryEntryType.generate
            let favOnly = Bool.random()

            let vm = VaultDetailViewModel(apiClient: apiClient, keychainStore: mock)
            vm.vault = DecryptedVault(id: UUID().uuidString, name: vaultName, entries: entries)
            vm.entries = entries
            vm.searchQuery = query
            vm.typeFilter = typeFilter
            vm.favoritesOnly = favOnly

            vm.lockVault()

            XCTAssertNil(vm.vault, "vault should be nil after lockVault()")
            XCTAssertTrue(vm.entries.isEmpty, "entries should be empty after lockVault()")
            XCTAssertEqual(vm.searchQuery, "", "searchQuery should be empty after lockVault()")
            XCTAssertNil(vm.typeFilter, "typeFilter should be nil after lockVault()")
            XCTAssertFalse(vm.favoritesOnly, "favoritesOnly should be false after lockVault()")
            XCTAssertNil(vm.error, "error should be nil after lockVault()")
        }
    }
}


// MARK: - Minimal Stub APIClient

/// Stub that only exists to satisfy the init requirement; no methods are called.
private final class StubAPIClient: APIClientProtocol, @unchecked Sendable {
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
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}
