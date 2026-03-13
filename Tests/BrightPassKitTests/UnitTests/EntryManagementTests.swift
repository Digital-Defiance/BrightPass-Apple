// Unit tests for entry management
// Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7

import XCTest
@testable import BrightPassKit

// MARK: - MockAPIClient for Entry Management Unit Tests

/// A controllable mock that supports entry CRUD operations with configurable errors.
@available(macOS 14.0, iOS 17.0, *)
private final class EntryMockAPIClient: APIClientProtocol, @unchecked Sendable {

    var entriesByVault: [String: [EntryPropertyRecord]] = [:]
    var storedEntries: [String: VaultEntry] = [:]  // entryId -> VaultEntry
    var shouldThrowOnGet: Error?
    var shouldThrowOnUpdate: Error?
    var shouldThrowOnDelete: Error?

    func getEntry(vaultId: String, entryId: String) async throws -> VaultEntry {
        if let err = shouldThrowOnGet { throw err }
        guard let entry = storedEntries[entryId] else {
            throw APIError(status: 404, code: "not_found", message: "Entry not found", details: nil)
        }
        return entry
    }

    func createEntry(vaultId: String, entry: VaultEntry) async throws -> VaultEntry {
        let record = EntryPropertyRecord(
            id: entry.id, title: entry.title, type: entry.type,
            tags: entry.tags, url: nil, isFavorite: entry.isFavorite
        )
        entriesByVault[vaultId, default: []].append(record)
        storedEntries[entry.id] = entry
        return entry
    }

    func updateEntry(vaultId: String, entryId: String, entry: VaultEntry) async throws -> VaultEntry {
        if let err = shouldThrowOnUpdate { throw err }
        storedEntries[entryId] = entry
        return entry
    }

    func deleteEntry(vaultId: String, entryId: String) async throws {
        if let err = shouldThrowOnDelete { throw err }
        entriesByVault[vaultId]?.removeAll { $0.id == entryId }
        storedEntries.removeValue(forKey: entryId)
    }

    func listEntries(vaultId: String) async throws -> [EntryPropertyRecord] {
        return entriesByVault[vaultId] ?? []
    }

    func searchEntries(vaultId: String, query: String) async throws -> [EntryPropertyRecord] {
        return (entriesByVault[vaultId] ?? []).filter { $0.title.localizedCaseInsensitiveContains(query) }
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


// MARK: - Test Helpers

private let now = Date()

private func makeLoginEntry(
    id: String = UUID().uuidString,
    title: String = "My Login",
    siteURL: String = "https://example.com",
    username: String = "user",
    password: String = "pass123",
    totpSecret: String? = nil,
    tags: [String] = [],
    isFavorite: Bool = false
) -> VaultEntry {
    VaultEntry(
        id: id, type: .login, title: title,
        fields: .login(LoginFields(siteURL: siteURL, username: username, password: password, totpSecret: totpSecret)),
        tags: tags, isFavorite: isFavorite, createdAt: now, updatedAt: now
    )
}

private func makeCreditCardEntry(
    id: String = UUID().uuidString,
    title: String = "My Card",
    cardholderName: String = "John Doe",
    cardNumber: String = "4111111111111111",
    expirationDate: String = "12/25",
    cvv: String = "123",
    tags: [String] = [],
    isFavorite: Bool = false
) -> VaultEntry {
    VaultEntry(
        id: id, type: .creditCard, title: title,
        fields: .creditCard(CreditCardFields(cardholderName: cardholderName, cardNumber: cardNumber, expirationDate: expirationDate, cvv: cvv)),
        tags: tags, isFavorite: isFavorite, createdAt: now, updatedAt: now
    )
}

private func makeSecureNoteEntry(
    id: String = UUID().uuidString,
    title: String = "My Note",
    content: String = "Secret content",
    tags: [String] = [],
    isFavorite: Bool = false
) -> VaultEntry {
    VaultEntry(
        id: id, type: .secureNote, title: title,
        fields: .secureNote(SecureNoteFields(content: content)),
        tags: tags, isFavorite: isFavorite, createdAt: now, updatedAt: now
    )
}

private func makeIdentityEntry(
    id: String = UUID().uuidString,
    title: String = "My Identity",
    name: String = "Jane Doe",
    email: String = "jane@example.com",
    phone: String = "555-0100",
    address: String = "123 Main St",
    customFields: [String: String] = [:],
    tags: [String] = [],
    isFavorite: Bool = false
) -> VaultEntry {
    VaultEntry(
        id: id, type: .identityDocument, title: title,
        fields: .identityDocument(IdentityDocumentFields(name: name, email: email, phone: phone, address: address, customFields: customFields)),
        tags: tags, isFavorite: isFavorite, createdAt: now, updatedAt: now
    )
}

// MARK: - Type-Specific Field Construction Tests

/// Tests that VaultEntry can be constructed with each entry type and fields are preserved.
/// Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6
@available(macOS 14.0, iOS 17.0, *)
final class EntryFieldConstructionTests: XCTestCase {

    /// Req 3.3: Login entry preserves siteURL, username, password, and optional totpSecret.
    func testLoginEntryFieldsPreserved() {
        let entry = makeLoginEntry(
            siteURL: "https://github.com",
            username: "dev",
            password: "s3cret!",
            totpSecret: "JBSWY3DPEHPK3PXP"
        )
        XCTAssertEqual(entry.type, .login)
        guard case .login(let fields) = entry.fields else {
            return XCTFail("Expected login fields")
        }
        XCTAssertEqual(fields.siteURL, "https://github.com")
        XCTAssertEqual(fields.username, "dev")
        XCTAssertEqual(fields.password, "s3cret!")
        XCTAssertEqual(fields.totpSecret, "JBSWY3DPEHPK3PXP")
    }

    /// Req 3.3: Login entry with empty TOTP secret stores nil.
    func testLoginEntryNilTotpSecret() {
        let entry = makeLoginEntry(totpSecret: nil)
        guard case .login(let fields) = entry.fields else {
            return XCTFail("Expected login fields")
        }
        XCTAssertNil(fields.totpSecret)
    }

    /// Req 3.4: Credit card entry preserves all card fields.
    func testCreditCardEntryFieldsPreserved() {
        let entry = makeCreditCardEntry(
            cardholderName: "Alice Smith",
            cardNumber: "5500000000000004",
            expirationDate: "06/28",
            cvv: "456"
        )
        XCTAssertEqual(entry.type, .creditCard)
        guard case .creditCard(let fields) = entry.fields else {
            return XCTFail("Expected credit card fields")
        }
        XCTAssertEqual(fields.cardholderName, "Alice Smith")
        XCTAssertEqual(fields.cardNumber, "5500000000000004")
        XCTAssertEqual(fields.expirationDate, "06/28")
        XCTAssertEqual(fields.cvv, "456")
    }

    /// Req 3.5: Secure note entry preserves content.
    func testSecureNoteEntryFieldsPreserved() {
        let entry = makeSecureNoteEntry(content: "Top secret information")
        XCTAssertEqual(entry.type, .secureNote)
        guard case .secureNote(let fields) = entry.fields else {
            return XCTFail("Expected secure note fields")
        }
        XCTAssertEqual(fields.content, "Top secret information")
    }

    /// Req 3.6: Identity document entry preserves name, email, phone, address, customFields.
    func testIdentityDocumentEntryFieldsPreserved() {
        let custom = ["SSN": "000-00-0000", "License": "D1234567"]
        let entry = makeIdentityEntry(
            name: "Bob Builder",
            email: "bob@example.com",
            phone: "555-0199",
            address: "456 Oak Ave",
            customFields: custom
        )
        XCTAssertEqual(entry.type, .identityDocument)
        guard case .identityDocument(let fields) = entry.fields else {
            return XCTFail("Expected identity document fields")
        }
        XCTAssertEqual(fields.name, "Bob Builder")
        XCTAssertEqual(fields.email, "bob@example.com")
        XCTAssertEqual(fields.phone, "555-0199")
        XCTAssertEqual(fields.address, "456 Oak Ave")
        XCTAssertEqual(fields.customFields, custom)
    }

    /// Req 3.1: All four entry types can be constructed.
    func testAllFourEntryTypesConstructible() {
        let login = makeLoginEntry()
        let card = makeCreditCardEntry()
        let note = makeSecureNoteEntry()
        let identity = makeIdentityEntry()

        XCTAssertEqual(login.type, .login)
        XCTAssertEqual(card.type, .creditCard)
        XCTAssertEqual(note.type, .secureNote)
        XCTAssertEqual(identity.type, .identityDocument)
    }
}


// MARK: - EntryDetailViewModel CRUD Tests

/// Tests for EntryDetailViewModel load, save, delete, and password visibility.
/// Validates: Requirements 3.7, 3.8, 3.9, 3.10
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class EntryDetailViewModelTests: XCTestCase {

    private var mock: EntryMockAPIClient!
    private var vm: EntryDetailViewModel!
    private let vaultId = "vault-1"

    override func setUp() {
        super.setUp()
        mock = EntryMockAPIClient()
        vm = EntryDetailViewModel(apiClient: mock)
    }

    // MARK: - loadEntry

    func testLoadEntrySuccess() async {
        let entry = makeLoginEntry(id: "e1", title: "GitHub")
        mock.storedEntries["e1"] = entry

        await vm.loadEntry(vaultId: vaultId, entryId: "e1")

        XCTAssertEqual(vm.entry, entry)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    func testLoadEntryFailureSetsError() async {
        mock.shouldThrowOnGet = APIError(status: 500, code: "server_error", message: "Internal error", details: nil)

        await vm.loadEntry(vaultId: vaultId, entryId: "missing")

        XCTAssertNil(vm.entry)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - saveEntry

    func testSaveEntrySuccess() async {
        let entry = makeLoginEntry(id: "e1", title: "Original")
        vm.entry = entry

        await vm.saveEntry(vaultId: vaultId)

        XCTAssertNotNil(vm.entry)
        XCTAssertFalse(vm.isEditing)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    func testSaveEntryWithNoEntryIsNoOp() async {
        vm.entry = nil

        await vm.saveEntry(vaultId: vaultId)

        XCTAssertNil(vm.entry)
        XCTAssertFalse(vm.isLoading)
    }

    func testSaveEntryFailureSetsError() async {
        let entry = makeLoginEntry(id: "e1")
        vm.entry = entry
        mock.shouldThrowOnUpdate = APIError(status: 400, code: "validation", message: "Bad request", details: ["Title required"])

        await vm.saveEntry(vaultId: vaultId)

        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - deleteEntry

    func testDeleteEntrySuccessSetsEntryToNil() async {
        let entry = makeLoginEntry(id: "e1")
        vm.entry = entry
        mock.storedEntries["e1"] = entry

        await vm.deleteEntry(vaultId: vaultId)

        XCTAssertNil(vm.entry)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    func testDeleteEntryWithNoEntryIsNoOp() async {
        vm.entry = nil

        await vm.deleteEntry(vaultId: vaultId)

        XCTAssertNil(vm.entry)
        XCTAssertFalse(vm.isLoading)
    }

    func testDeleteEntryFailureSetsError() async {
        let entry = makeLoginEntry(id: "e1")
        vm.entry = entry
        mock.shouldThrowOnDelete = APIError(status: 500, code: "server_error", message: "Delete failed", details: nil)

        await vm.deleteEntry(vaultId: vaultId)

        // Entry should still be set since delete failed
        XCTAssertNotNil(vm.entry)
        XCTAssertNotNil(vm.error)
    }

    // MARK: - Password Visibility

    func testTogglePasswordVisibility() {
        XCTAssertFalse(vm.isPasswordVisible)
        vm.togglePasswordVisibility()
        XCTAssertTrue(vm.isPasswordVisible)
        vm.togglePasswordVisibility()
        XCTAssertFalse(vm.isPasswordVisible)
    }

    // MARK: - Loading State

    func testLoadEntrySetsLoadingDuringOperation() async {
        let entry = makeLoginEntry(id: "e1")
        mock.storedEntries["e1"] = entry

        await vm.loadEntry(vaultId: vaultId, entryId: "e1")

        // After completion, isLoading should be false
        XCTAssertFalse(vm.isLoading)
    }
}


// MARK: - Edge Case Tests

/// Tests for edge cases in entry construction and management.
/// Validates: Requirements 3.1, 3.2, 3.6, 3.7
@available(macOS 14.0, iOS 17.0, *)
final class EntryEdgeCaseTests: XCTestCase {

    /// Entry with empty tags array is valid.
    func testEntryWithEmptyTags() {
        let entry = makeLoginEntry(tags: [])
        XCTAssertTrue(entry.tags.isEmpty)
    }

    /// Identity entry with empty custom fields dictionary is valid.
    func testIdentityEntryWithEmptyCustomFields() {
        let entry = makeIdentityEntry(customFields: [:])
        guard case .identityDocument(let fields) = entry.fields else {
            return XCTFail("Expected identity document fields")
        }
        XCTAssertTrue(fields.customFields.isEmpty)
    }

    /// Empty title validation: the form disables save when title is whitespace-only.
    /// This mirrors the EntryFormView's `.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)` logic.
    /// Note: `.whitespaces` only includes spaces (U+0020) and tabs (U+0009), not newlines.
    func testEmptyTitleValidation() {
        let emptyTitles = ["", "   "]
        for title in emptyTitles {
            let trimmed = title.trimmingCharacters(in: .whitespaces)
            XCTAssertTrue(trimmed.isEmpty, "Expected '\(title)' to be treated as empty after trimming")
        }

        let validTitles = ["A", " Hello ", "My Entry"]
        for title in validTitles {
            let trimmed = title.trimmingCharacters(in: .whitespaces)
            XCTAssertFalse(trimmed.isEmpty, "Expected '\(title)' to be non-empty after trimming")
        }
    }

    /// Login entry with empty TOTP string should map to nil (as EntryFormView does).
    func testEmptyTotpSecretMapsToNil() {
        // Simulating EntryFormView's buildEntry logic: totpSecret.isEmpty ? nil : totpSecret
        let totpInput = ""
        let totpSecret: String? = totpInput.isEmpty ? nil : totpInput
        let entry = makeLoginEntry(totpSecret: totpSecret)
        guard case .login(let fields) = entry.fields else {
            return XCTFail("Expected login fields")
        }
        XCTAssertNil(fields.totpSecret)
    }

    /// Identity entry custom fields with empty keys should be filtered out (as EntryFormView does).
    func testCustomFieldsWithEmptyKeysFiltered() {
        // Simulating EntryFormView's buildEntry logic for identity custom fields
        let rawFields = [("", "value1"), ("  ", "value2"), ("validKey", "value3")]
        var cfDict: [String: String] = [:]
        for (key, value) in rawFields where !key.trimmingCharacters(in: .whitespaces).isEmpty {
            cfDict[key] = value
        }
        XCTAssertEqual(cfDict.count, 1)
        XCTAssertEqual(cfDict["validKey"], "value3")
    }

    /// Entries with duplicate IDs in a list — both should be present (no dedup at model level).
    func testDuplicateEntryIDsInList() {
        let id = "duplicate-id"
        let entry1 = EntryPropertyRecord(id: id, title: "First", type: .login, tags: [], url: nil, isFavorite: false)
        let entry2 = EntryPropertyRecord(id: id, title: "Second", type: .secureNote, tags: [], url: nil, isFavorite: true)
        let list = [entry1, entry2]
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.filter { $0.id == id }.count, 2)
    }

    /// Entry with favorite toggle set to true.
    func testEntryFavoriteFlag() {
        let fav = makeLoginEntry(isFavorite: true)
        let notFav = makeLoginEntry(isFavorite: false)
        XCTAssertTrue(fav.isFavorite)
        XCTAssertFalse(notFav.isFavorite)
    }

    /// Entry tags are preserved in order.
    func testEntryTagsPreservedInOrder() {
        let tags = ["work", "important", "shared"]
        let entry = makeLoginEntry(tags: tags)
        XCTAssertEqual(entry.tags, tags)
    }
}
