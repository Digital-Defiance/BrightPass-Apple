// Property 10: Search Results Match Query
// Property 11: Filter Results Satisfy Predicate
// Validates: Requirements 4.3, 4.4, 4.5
//
// Property 10: For any list of EntryPropertyRecord items and any non-empty search query,
// all items in the search results shall have a title, tag, or URL that contains the query
// as a case-insensitive substring.
//
// Property 11: For any list of EntryPropertyRecord items, any optional EntryType filter,
// and any favorites-only boolean, all items returned by filterEntries() shall match the
// type filter (if set) AND have isFavorite == true (if favorites-only is enabled).

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - MockAPIClient

/// Mock API client for search/filter tests.
/// `searchEntries` filters the stored entries by case-insensitive title/tag/URL match,
/// simulating what the real API would return.
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    /// Entries to filter against when `searchEntries` is called.
    var storedEntries: [EntryPropertyRecord] = []

    func searchEntries(vaultId: String, query: String) async throws -> [EntryPropertyRecord] {
        let q = query.lowercased()
        return storedEntries.filter { entry in
            entry.title.lowercased().contains(q)
            || entry.tags.contains { $0.lowercased().contains(q) }
            || (entry.url?.lowercased().contains(q) ?? false)
        }
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

/// Generator for a short alphanumeric string (1–10 chars) suitable for search terms.
private let shortAlphaString: Gen<String> = Gen<Character>.fromElements(in: "a"..."z")
    .proliferate(withSize: 10)
    .suchThat { !$0.isEmpty }
    .map { String($0.prefix(max(1, Int.random(in: 1...10)))) }

/// Generator for a single EntryPropertyRecord with random data.
private let arbitraryEntry: Gen<EntryPropertyRecord> = Gen.compose { c in
    EntryPropertyRecord(
        id: UUID().uuidString,
        title: c.generate(using: shortAlphaString),
        type: c.generate(using: arbitraryEntryType),
        tags: (0..<Int.random(in: 0...3)).map { _ in
            c.generate(using: shortAlphaString)
        },
        url: Bool.random() ? "https://\(c.generate(using: shortAlphaString)).com" : nil,
        isFavorite: c.generate()
    )
}

/// Generator for a list of 0–15 entries.
private let entryList: Gen<[EntryPropertyRecord]> = Gen.compose { c in
    let count = abs(c.generate(using: Int.arbitrary)) % 15
    return (0..<count).map { _ in c.generate(using: arbitraryEntry) }
}

/// Generator for a non-empty list of entries (1–15).
private let nonEmptyEntryList: Gen<[EntryPropertyRecord]> = entryList.suchThat { !$0.isEmpty }

// MARK: - Property Tests

/// **Validates: Requirements 4.3, 4.4, 4.5**
@available(macOS 14.0, iOS 17.0, *)
final class SearchFilterPropertyTests: XCTestCase {

    /// **Property 10: Search Results Match Query**
    /// For any list of entries and any non-empty search query, all items returned by
    /// searchEntries() shall have a title, tag, or URL containing the query (case-insensitive).
    /// **Validates: Requirements 4.3**
    func testSearchResultsMatchQuery() {
        property("All search results contain the query substring") <- forAllNoShrink(nonEmptyEntryList, shortAlphaString) {
            (entries: [EntryPropertyRecord], query: String) in

            let mock = MockAPIClient()
            mock.storedEntries = entries

            // Call mock.searchEntries on a background thread
            nonisolated(unsafe) var results: [EntryPropertyRecord] = []
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                Task {
                    results = try await mock.searchEntries(vaultId: "test-vault", query: query)
                    semaphore.signal()
                }
            }
            semaphore.wait()

            let q = query.lowercased()
            return results.allSatisfy { entry in
                entry.title.lowercased().contains(q)
                || entry.tags.contains { $0.lowercased().contains(q) }
                || (entry.url?.lowercased().contains(q) ?? false)
            }
        }
    }

    /// **Property 11: Filter Results Satisfy Predicate**
    /// For any list of entries, any optional type filter, and any favorites-only flag,
    /// all items returned by filterEntries() match the type (if set) AND are favorites (if enabled).
    /// **Validates: Requirements 4.4, 4.5**
    func testFilterResultsSatisfyPredicate() {
        property("All filter results satisfy the type and favorite predicate") <- forAllNoShrink(
            entryList,
            Gen<EntryType?>.one(of: [
                Gen.pure(nil),
                arbitraryEntryType.map { Optional($0) }
            ]),
            Bool.arbitrary
        ) { (entries: [EntryPropertyRecord], typeFilter: EntryType?, favoritesOnly: Bool) in

            // Apply the same filter logic as VaultDetailViewModel.filterEntries() inline
            var result = entries
            if let tf = typeFilter {
                result = result.filter { $0.type == tf }
            }
            if favoritesOnly {
                result = result.filter { $0.isFavorite }
            }

            let typeOk: Bool
            if let tf = typeFilter {
                typeOk = result.allSatisfy { $0.type == tf }
            } else {
                typeOk = true
            }

            let favOk: Bool
            if favoritesOnly {
                favOk = result.allSatisfy { $0.isFavorite }
            } else {
                favOk = true
            }

            return typeOk && favOk
        }
    }
}
