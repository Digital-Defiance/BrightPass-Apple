// Unit tests for sharing, emergency access, import, and audit log
// Validates: Requirements 8.3, 8.5, 9.3, 9.6, 10.2, 10.4, 11.3

import XCTest
@testable import BrightPassKit

// MARK: - Mock APIClient

@available(macOS 14.0, iOS 17.0, *)
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    // Sharing
    var sharedMembers: [SharedMember] = []
    var shareError: Error?
    var revokeError: Error?

    // Emergency Access
    var emergencyConfig: EmergencyAccessConfig?
    var emergencyConfigError: Error?
    var recoverResult: DecryptedVault?
    var recoverError: Error?
    var recoverVaultCalled = false

    // Import
    var importResult: ImportResult?
    var importError: Error?

    // Audit Log
    var auditEntries: [AuditLogEntry] = []
    var auditError: Error?

    // MARK: - Sharing

    func shareVault(vaultId: String, memberId: String, permission: SharePermission) async throws {
        if let err = shareError { throw err }
        sharedMembers.append(SharedMember(id: UUID().uuidString, memberId: memberId, permission: permission))
    }

    func revokeShare(vaultId: String, memberId: String) async throws {
        if let err = revokeError { throw err }
        sharedMembers.removeAll { $0.memberId == memberId }
    }

    func listSharedMembers(vaultId: String) async throws -> [SharedMember] {
        if let err = shareError { throw err }
        return sharedMembers
    }

    // MARK: - Emergency Access

    func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws {
        if let err = emergencyConfigError { throw err }
        emergencyConfig = config
    }

    func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig {
        if let err = emergencyConfigError { throw err }
        guard let cfg = emergencyConfig else {
            throw APIError(status: 404, code: "not_found", message: "No config", details: nil)
        }
        return cfg
    }

    func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault {
        recoverVaultCalled = true
        if let err = recoverError { throw err }
        guard let result = recoverResult else {
            throw APIError(status: 500, code: "no_mock", message: "No mock recovery", details: nil)
        }
        return result
    }

    // MARK: - Import

    func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult {
        if let err = importError { throw err }
        guard let result = importResult else {
            throw APIError(status: 500, code: "no_mock", message: "No mock import", details: nil)
        }
        return result
    }

    // MARK: - Audit Log

    func getAuditLog(vaultId: String) async throws -> [AuditLogEntry] {
        if let err = auditError { throw err }
        return auditEntries
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
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}


// MARK: - ShareVaultViewModel Tests

/// Validates: Requirements 8.3, 8.5
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class ShareVaultViewModelTests: XCTestCase {

    private var mock: MockAPIClient!
    private var vm: ShareVaultViewModel!

    override func setUp() {
        super.setUp()
        mock = MockAPIClient()
        vm = ShareVaultViewModel(apiClient: mock)
    }

    /// Req 8.3: Sharing a vault adds the member to the shared list.
    func testShareVaultAddsMember() async {
        await vm.shareVault(vaultId: "v1", memberId: "user-42", permission: .readWrite)

        XCTAssertTrue(vm.sharedMembers.contains { $0.memberId == "user-42" })
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    /// Req 8.5: Revoking access removes the member from the list.
    func testRevokeAccessRemovesMember() async {
        mock.sharedMembers = [
            SharedMember(id: "s1", memberId: "user-1", permission: .readOnly),
            SharedMember(id: "s2", memberId: "user-2", permission: .readWrite)
        ]
        await vm.loadSharedMembers(vaultId: "v1")
        XCTAssertEqual(vm.sharedMembers.count, 2)

        await vm.revokeAccess(vaultId: "v1", memberId: "user-1")

        XCTAssertEqual(vm.sharedMembers.count, 1)
        XCTAssertFalse(vm.sharedMembers.contains { $0.memberId == "user-1" })
        XCTAssertNil(vm.error)
    }

    /// Share failure sets error.
    func testShareVaultFailureSetsError() async {
        mock.shareError = APIError(status: 403, code: "forbidden", message: "Not allowed", details: nil)

        await vm.shareVault(vaultId: "v1", memberId: "user-42", permission: .readOnly)

        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    /// Revoke failure sets error and does not remove member.
    func testRevokeFailureKeepsMember() async {
        vm.sharedMembers = [SharedMember(id: "s1", memberId: "user-1", permission: .readOnly)]
        mock.revokeError = APIError(status: 500, code: "server_error", message: "Failed", details: nil)

        await vm.revokeAccess(vaultId: "v1", memberId: "user-1")

        XCTAssertNotNil(vm.error)
        XCTAssertEqual(vm.sharedMembers.count, 1)
    }
}


// MARK: - EmergencyAccessViewModel Tests

/// Validates: Requirements 9.3, 9.6
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class EmergencyAccessViewModelTests: XCTestCase {

    private var mock: MockAPIClient!
    private var vm: EmergencyAccessViewModel!

    override func setUp() {
        super.setUp()
        mock = MockAPIClient()
        vm = EmergencyAccessViewModel(apiClient: mock)
    }

    /// Req 9.3: Configuring emergency access stores the config.
    func testConfigureSuccess() async {
        await vm.configure(vaultId: "v1", totalShares: 5, threshold: 3)

        XCTAssertNotNil(vm.config)
        XCTAssertEqual(vm.config?.totalShares, 5)
        XCTAssertEqual(vm.config?.threshold, 3)
        XCTAssertNil(vm.error)
    }

    /// Req 9.6: Successful recovery returns a vault.
    func testRecoverSuccess() async {
        let expectedVault = DecryptedVault(id: "v1", name: "Recovered", entries: [])
        mock.recoverResult = expectedVault
        vm.config = EmergencyAccessConfig(totalShares: 3, threshold: 2, trustees: [])

        let result = await vm.recover(vaultId: "v1", shares: ["share1", "share2"])

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Recovered")
        XCTAssertNotNil(vm.recoveredVault)
        XCTAssertNil(vm.error)
    }

    /// Req 9.7: Insufficient shares produces error without API call.
    func testInsufficientSharesProducesError() async {
        vm.config = EmergencyAccessConfig(totalShares: 5, threshold: 3, trustees: [])

        let result = await vm.recover(vaultId: "v1", shares: ["share1"])

        XCTAssertNil(result)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(mock.recoverVaultCalled)
    }

    /// Recovery failure sets error.
    func testRecoverFailureSetsError() async {
        vm.config = EmergencyAccessConfig(totalShares: 3, threshold: 2, trustees: [])
        mock.recoverError = APIError(status: 400, code: "invalid_shares", message: "Bad shares", details: nil)

        let result = await vm.recover(vaultId: "v1", shares: ["share1", "share2"])

        XCTAssertNil(result)
        XCTAssertNotNil(vm.error)
    }
}


// MARK: - ImportViewModel Tests

/// Validates: Requirements 10.2, 10.4
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class ImportViewModelTests: XCTestCase {

    private var mock: MockAPIClient!
    private var vm: ImportViewModel!

    override func setUp() {
        super.setUp()
        mock = MockAPIClient()
        vm = ImportViewModel(apiClient: mock)
    }

    /// Req 10.4: Successful import shows result summary.
    func testImportSuccess() async {
        mock.importResult = ImportResult(importedCount: 15, errors: [])

        await vm.importFile(vaultId: "v1", source: .lastPassCSV, fileData: Data("csv-data".utf8))

        XCTAssertNotNil(vm.result)
        XCTAssertEqual(vm.result?.importedCount, 15)
        XCTAssertTrue(vm.result?.errors.isEmpty ?? false)
        XCTAssertNil(vm.error)
    }

    /// Req 10.4: Import with partial errors shows error summary.
    func testImportWithErrors() async {
        mock.importResult = ImportResult(importedCount: 8, errors: ["Row 3: invalid format", "Row 7: missing field"])

        await vm.importFile(vaultId: "v1", source: .chromeCSV, fileData: Data("csv-data".utf8))

        XCTAssertNotNil(vm.result)
        XCTAssertEqual(vm.result?.importedCount, 8)
        XCTAssertEqual(vm.result?.errors.count, 2)
    }

    /// Req 10.2: Each import source can be used.
    func testAllImportSourcesAccepted() async {
        for source in ImportSource.allCases {
            mock.importResult = ImportResult(importedCount: 1, errors: [])
            await vm.importFile(vaultId: "v1", source: source, fileData: Data("data".utf8))
            XCTAssertNotNil(vm.result, "Import should succeed for source: \(source)")
        }
    }

    /// Import failure sets error.
    func testImportFailureSetsError() async {
        mock.importError = APIError(status: 400, code: "bad_format", message: "Unsupported format", details: nil)

        await vm.importFile(vaultId: "v1", source: .bitwardenJSON, fileData: Data("bad".utf8))

        XCTAssertNil(vm.result)
        XCTAssertNotNil(vm.error)
    }

    /// Req 10.5: onImportSuccess callback fires on success.
    func testOnImportSuccessCallbackFires() async {
        mock.importResult = ImportResult(importedCount: 5, errors: [])
        var callbackFired = false
        vm.onImportSuccess = { callbackFired = true }

        await vm.importFile(vaultId: "v1", source: .firefoxCSV, fileData: Data("data".utf8))

        XCTAssertTrue(callbackFired)
    }
}


// MARK: - AuditLogViewModel Tests

/// Validates: Requirements 11.3
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class AuditLogViewModelTests: XCTestCase {

    private var mock: MockAPIClient!
    private var vm: AuditLogViewModel!

    override func setUp() {
        super.setUp()
        mock = MockAPIClient()
        vm = AuditLogViewModel(apiClient: mock)
    }

    /// Req 11.3: Entries are displayed with action, memberId, timestamp.
    func testLoadAuditLogSuccess() async {
        let now = Date()
        mock.auditEntries = [
            AuditLogEntry(id: "1", action: "create_entry", memberId: "user-1", timestamp: now.addingTimeInterval(-60), metadata: nil),
            AuditLogEntry(id: "2", action: "delete_entry", memberId: "user-2", timestamp: now, metadata: ["entryId": "e1"])
        ]

        await vm.loadAuditLog(vaultId: "v1")

        XCTAssertEqual(vm.entries.count, 2)
        // Newest first
        XCTAssertEqual(vm.entries.first?.id, "2")
        XCTAssertEqual(vm.entries.last?.id, "1")
        XCTAssertNil(vm.error)
    }

    /// Empty audit log displays no entries.
    func testEmptyAuditLog() async {
        mock.auditEntries = []

        await vm.loadAuditLog(vaultId: "v1")

        XCTAssertTrue(vm.entries.isEmpty)
        XCTAssertNil(vm.error)
    }

    /// Req 11.3: Metadata is preserved in entries.
    func testMetadataDisplay() async {
        mock.auditEntries = [
            AuditLogEntry(id: "1", action: "share_vault", memberId: "user-1", timestamp: Date(), metadata: ["target": "user-2", "permission": "readOnly"])
        ]

        await vm.loadAuditLog(vaultId: "v1")

        XCTAssertEqual(vm.entries.first?.metadata?["target"], "user-2")
        XCTAssertEqual(vm.entries.first?.metadata?["permission"], "readOnly")
    }

    /// Audit log failure sets error.
    func testLoadAuditLogFailure() async {
        mock.auditError = APIError(status: 500, code: "server_error", message: "Failed", details: nil)

        await vm.loadAuditLog(vaultId: "v1")

        XCTAssertTrue(vm.entries.isEmpty)
        XCTAssertNotNil(vm.error)
    }
}
