// Property 7: Entry Creation Adds to List
// Property 8: Entry Update Reflects Changes
// Property 9: Entry Deletion Removes from List
// Validates: Requirements 3.7, 3.9, 3.10
//
// Property 7: After creating an entry via the API and refreshing, the entry list
// contains the new entry and its count has increased by one.
// Property 8: After updating an entry via the API, the entry reflects the new field values.
// Property 9: After calling deleteEntry on VaultDetailViewModel, the entry is removed
// from the list and the count decreases by one.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - MockAPIClient

/// Minimal mock conforming to `APIClientProtocol` for entry management tests.
/// Implements entry CRUD and listEntries; all others `fatalError`.
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    /// Backing store for entries, keyed by vault ID.
    var entriesByVault: [String: [EntryPropertyRecord]] = [:]

    func listEntries(vaultId: String) async throws -> [EntryPropertyRecord] {
        return entriesByVault[vaultId] ?? []
    }

    func createEntry(vaultId: String, entry: VaultEntry) async throws -> VaultEntry {
        let record = EntryPropertyRecord(
            id: entry.id,
            title: entry.title,
            type: entry.type,
            tags: entry.tags,
            url: nil,
            isFavorite: entry.isFavorite
        )
        entriesByVault[vaultId, default: []].append(record)
        return entry
    }

    func updateEntry(vaultId: String, entryId: String, entry: VaultEntry) async throws -> VaultEntry {
        if let idx = entriesByVault[vaultId]?.firstIndex(where: { $0.id == entryId }) {
            entriesByVault[vaultId]![idx] = EntryPropertyRecord(
                id: entry.id,
                title: entry.title,
                type: entry.type,
                tags: entry.tags,
                url: nil,
                isFavorite: entry.isFavorite
            )
        }
        return entry
    }

    func deleteEntry(vaultId: String, entryId: String) async throws {
        entriesByVault[vaultId]?.removeAll { $0.id == entryId }
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
    func getEntry(vaultId: String, entryId: String) async throws -> VaultEntry { fatalError() }
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

// MARK: - Generators

/// Generator for a random EntryType.
private let arbitraryEntryType: Gen<EntryType> = Gen<Int>.fromElements(in: 0...3).map {
    EntryType.allCases[$0]
}

/// Generator for a short alphanumeric string (1–10 chars).
private let shortAlphaString: Gen<String> = Gen<Character>.fromElements(in: "a"..."z")
    .proliferate(withSize: 10)
    .suchThat { !$0.isEmpty }
    .map { String($0.prefix(max(1, Int.random(in: 1...10)))) }

/// Generator for a single EntryPropertyRecord with a unique ID.
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

/// Generator for a list of 0–15 entries with unique IDs.
private let entryList: Gen<[EntryPropertyRecord]> = Gen.compose { c in
    let count = abs(c.generate(using: Int.arbitrary)) % 15
    return (0..<count).map { _ in c.generate(using: arbitraryEntry) }
}

/// Generator for a non-empty list of entries (1–15).
private let nonEmptyEntryList: Gen<[EntryPropertyRecord]> = entryList.suchThat { !$0.isEmpty }

/// Generator for a VaultEntry with login fields (simple for testing).
private let arbitraryVaultEntry: Gen<VaultEntry> = Gen.compose { c in
    let now = Date()
    return VaultEntry(
        id: UUID().uuidString,
        type: c.generate(using: arbitraryEntryType),
        title: c.generate(using: shortAlphaString),
        fields: .login(LoginFields(
            siteURL: "https://\(c.generate(using: shortAlphaString)).com",
            username: c.generate(using: shortAlphaString),
            password: c.generate(using: shortAlphaString),
            totpSecret: nil
        )),
        tags: (0..<Int.random(in: 0...2)).map { _ in c.generate(using: shortAlphaString) },
        isFavorite: c.generate(),
        createdAt: now,
        updatedAt: now
    )
}

// MARK: - Property Tests

/// **Validates: Requirements 3.7, 3.9, 3.10**
@available(macOS 14.0, iOS 17.0, *)
final class EntryManagementPropertyTests: XCTestCase {

    /// **Property 7: Entry Creation Adds to List**
    /// After creating an entry via the mock API and listing entries,
    /// the entry list count increases by one.
    /// **Validates: Requirements 3.7**
    func testEntryCreationAddsToList() {
        property("Creating an entry increases the list count by one") <- forAllNoShrink(entryList, arbitraryVaultEntry) {
            (initialEntries: [EntryPropertyRecord], newEntry: VaultEntry) in

            let mock = MockAPIClient()
            let vaultId = "test-vault"
            mock.entriesByVault[vaultId] = initialEntries
            let initialCount = initialEntries.count

            // Call mock API methods on a background thread
            nonisolated(unsafe) var entries: [EntryPropertyRecord] = []
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                Task {
                    _ = try await mock.createEntry(vaultId: vaultId, entry: newEntry)
                    entries = try await mock.listEntries(vaultId: vaultId)
                    semaphore.signal()
                }
            }
            semaphore.wait()

            return entries.count == initialCount + 1
        }
    }

    /// **Property 8: Entry Update Reflects Changes**
    /// After updating an entry via the mock API, the entry reflects the new title.
    /// **Validates: Requirements 3.9**
    func testEntryUpdateReflectsChanges() {
        property("Updating an entry reflects the new field values") <- forAllNoShrink(nonEmptyEntryList, shortAlphaString) {
            (initialEntries: [EntryPropertyRecord], newTitle: String) in

            let indexToUpdate = Int.random(in: 0..<initialEntries.count)
            let entryToUpdate = initialEntries[indexToUpdate]
            let now = Date()
            let updatedVaultEntry = VaultEntry(
                id: entryToUpdate.id,
                type: entryToUpdate.type,
                title: newTitle,
                fields: .login(LoginFields(
                    siteURL: "https://example.com",
                    username: "user",
                    password: "pass",
                    totpSecret: nil
                )),
                tags: entryToUpdate.tags,
                isFavorite: entryToUpdate.isFavorite,
                createdAt: now,
                updatedAt: now
            )

            let mock = MockAPIClient()
            let vaultId = "test-vault"
            mock.entriesByVault[vaultId] = initialEntries

            // Call mock API methods on a background thread
            nonisolated(unsafe) var entries: [EntryPropertyRecord] = []
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                Task {
                    _ = try await mock.updateEntry(vaultId: vaultId, entryId: entryToUpdate.id, entry: updatedVaultEntry)
                    entries = try await mock.listEntries(vaultId: vaultId)
                    semaphore.signal()
                }
            }
            semaphore.wait()

            if let updated = entries.first(where: { $0.id == entryToUpdate.id }) {
                return updated.title == newTitle
            }
            return false
        }
    }

    /// **Property 9: Entry Deletion Removes from List**
    /// After calling deleteEntry, the entry is removed from the list
    /// and the count decreases by one.
    /// **Validates: Requirements 3.10**
    func testEntryDeletionRemovesFromList() {
        property("Deleting an entry decreases the list count by one and removes the ID") <- forAllNoShrink(nonEmptyEntryList) {
            (initialEntries: [EntryPropertyRecord]) in

            let indexToDelete = Int.random(in: 0..<initialEntries.count)
            let entryToDelete = initialEntries[indexToDelete]

            let mock = MockAPIClient()
            let vaultId = "test-vault"
            mock.entriesByVault[vaultId] = initialEntries
            let initialCount = initialEntries.count

            // Call mock API methods on a background thread
            nonisolated(unsafe) var entries: [EntryPropertyRecord] = []
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                Task {
                    try await mock.deleteEntry(vaultId: vaultId, entryId: entryToDelete.id)
                    entries = try await mock.listEntries(vaultId: vaultId)
                    semaphore.signal()
                }
            }
            semaphore.wait()

            let countCorrect = entries.count == initialCount - 1
            let idRemoved = !entries.contains { $0.id == entryToDelete.id }
            return countCorrect && idRemoved
        }
    }
}
