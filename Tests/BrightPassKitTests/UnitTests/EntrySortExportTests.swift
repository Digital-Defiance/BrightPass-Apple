// Unit tests for entry sorting and data export
// Validates: Requirements 24.1, 24.2, 24.4, 25.2, 25.3, 25.5

import XCTest
@testable import BrightPassKit

// MARK: - Mock APIClient

@available(macOS 14.0, iOS 17.0, *)
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    var exportResult: Data?
    var exportError: Error?
    var exportCalledWithFormat: ExportFormat?

    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data {
        exportCalledWithFormat = format
        if let err = exportError { throw err }
        return exportResult ?? Data()
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
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
}

// MARK: - Test Helpers

private func makeEntry(_ title: String, type: EntryType = .login, favorite: Bool = false,
                        createdAt: Date? = nil, updatedAt: Date? = nil) -> EntryPropertyRecord {
    EntryPropertyRecord(id: UUID().uuidString, title: title, type: type,
                        tags: [], url: nil, isFavorite: favorite,
                        createdAt: createdAt, updatedAt: updatedAt)
}


// MARK: - Entry Sort Tests

@available(macOS 14.0, iOS 17.0, *)
final class EntrySortTests: XCTestCase {

    @MainActor
    func testNameAscending() {
        let vm = EntrySortViewModel()
        vm.selectedSort = .nameAscending
        let entries = [makeEntry("Charlie"), makeEntry("Alpha"), makeEntry("Bravo")]
        let sorted = vm.sortEntries(entries)
        XCTAssertEqual(sorted.map(\.title), ["Alpha", "Bravo", "Charlie"])
    }

    @MainActor
    func testNameDescending() {
        let vm = EntrySortViewModel()
        vm.selectedSort = .nameDescending
        let entries = [makeEntry("Alpha"), makeEntry("Charlie"), makeEntry("Bravo")]
        let sorted = vm.sortEntries(entries)
        XCTAssertEqual(sorted.map(\.title), ["Charlie", "Bravo", "Alpha"])
    }

    @MainActor
    func testDateModifiedNewest() {
        let vm = EntrySortViewModel()
        vm.selectedSort = .dateModifiedNewest
        let old = Date(timeIntervalSince1970: 1000)
        let mid = Date(timeIntervalSince1970: 2000)
        let recent = Date(timeIntervalSince1970: 3000)
        let entries = [makeEntry("A", updatedAt: old), makeEntry("B", updatedAt: recent), makeEntry("C", updatedAt: mid)]
        let sorted = vm.sortEntries(entries)
        XCTAssertEqual(sorted.map(\.title), ["B", "C", "A"])
    }

    @MainActor
    func testDateModifiedOldest() {
        let vm = EntrySortViewModel()
        vm.selectedSort = .dateModifiedOldest
        let old = Date(timeIntervalSince1970: 1000)
        let mid = Date(timeIntervalSince1970: 2000)
        let recent = Date(timeIntervalSince1970: 3000)
        let entries = [makeEntry("A", updatedAt: recent), makeEntry("B", updatedAt: old), makeEntry("C", updatedAt: mid)]
        let sorted = vm.sortEntries(entries)
        XCTAssertEqual(sorted.map(\.title), ["B", "C", "A"])
    }

    @MainActor
    func testDateCreatedNewest() {
        let vm = EntrySortViewModel()
        vm.selectedSort = .dateCreatedNewest
        let old = Date(timeIntervalSince1970: 100)
        let recent = Date(timeIntervalSince1970: 500)
        let entries = [makeEntry("A", createdAt: old), makeEntry("B", createdAt: recent)]
        let sorted = vm.sortEntries(entries)
        XCTAssertEqual(sorted.map(\.title), ["B", "A"])
    }

    @MainActor
    func testDateCreatedOldest() {
        let vm = EntrySortViewModel()
        vm.selectedSort = .dateCreatedOldest
        let old = Date(timeIntervalSince1970: 100)
        let recent = Date(timeIntervalSince1970: 500)
        let entries = [makeEntry("A", createdAt: recent), makeEntry("B", createdAt: old)]
        let sorted = vm.sortEntries(entries)
        XCTAssertEqual(sorted.map(\.title), ["B", "A"])
    }

    @MainActor
    func testSortByEntryType() {
        let vm = EntrySortViewModel()
        vm.selectedSort = .entryType
        let entries = [
            makeEntry("Z", type: .secureNote),
            makeEntry("A", type: .creditCard),
            makeEntry("M", type: .login),
            makeEntry("B", type: .identityDocument)
        ]
        let sorted = vm.sortEntries(entries)
        let types = sorted.map(\.type)
        // Verify types are in ascending rawValue order
        for i in 0..<types.count - 1 {
            XCTAssertTrue(types[i].rawValue <= types[i + 1].rawValue)
        }
    }

    @MainActor
    func testSortAppliedAfterFilter() {
        let vm = EntrySortViewModel()
        vm.selectedSort = .nameAscending
        // Simulate filtered entries (only logins)
        let filtered = [
            makeEntry("Zeta", type: .login),
            makeEntry("Alpha", type: .login),
            makeEntry("Mu", type: .login)
        ]
        let sorted = vm.sortEntries(filtered)
        XCTAssertEqual(sorted.map(\.title), ["Alpha", "Mu", "Zeta"])
    }

    @MainActor
    func testDefaultSortIsNameAscending() {
        let vm = EntrySortViewModel()
        XCTAssertEqual(vm.selectedSort, .nameAscending)
    }

    @MainActor
    func testEmptyListReturnsEmpty() {
        let vm = EntrySortViewModel()
        let sorted = vm.sortEntries([])
        XCTAssertTrue(sorted.isEmpty)
    }
}

// MARK: - Export Tests

@available(macOS 14.0, iOS 17.0, *)
final class ExportTests: XCTestCase {

    @MainActor
    func testExportCSVFormat() async {
        let mock = MockAPIClient()
        let csvData = "title,username,password\nTest,user,pass".data(using: .utf8)!
        mock.exportResult = csvData

        let vm = ExportViewModel(apiClient: mock)
        vm.selectedFormat = .csv
        await vm.exportEntries(vaultId: "v1")

        XCTAssertEqual(mock.exportCalledWithFormat, .csv)
        XCTAssertEqual(vm.exportedData, csvData)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor
    func testExportJSONFormat() async {
        let mock = MockAPIClient()
        let jsonData = "[{\"title\":\"Test\"}]".data(using: .utf8)!
        mock.exportResult = jsonData

        let vm = ExportViewModel(apiClient: mock)
        vm.selectedFormat = .json
        await vm.exportEntries(vaultId: "v1")

        XCTAssertEqual(mock.exportCalledWithFormat, .json)
        XCTAssertEqual(vm.exportedData, jsonData)
        XCTAssertNil(vm.error)
    }

    @MainActor
    func testExportErrorDisplaysError() async {
        let mock = MockAPIClient()
        mock.exportError = APIError(status: 500, code: "server_error",
                                    message: "Export failed", details: nil)

        let vm = ExportViewModel(apiClient: mock)
        await vm.exportEntries(vaultId: "v1")

        XCTAssertNotNil(vm.error)
        XCTAssertNil(vm.exportedData)
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor
    func testExportDefaultFormatIsCSV() {
        let mock = MockAPIClient()
        let vm = ExportViewModel(apiClient: mock)
        XCTAssertEqual(vm.selectedFormat, .csv)
    }
}
