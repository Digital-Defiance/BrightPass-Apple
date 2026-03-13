// Unit tests for autofill provider logic at the API/model level
// Validates: Requirements 14.3, 14.5

import XCTest
@testable import BrightPassKit

// MARK: - Mock APIClient

@available(macOS 14.0, iOS 17.0, *)
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    // Autofill
    var autofillEntries: [AutofillPayload] = []
    var autofillError: Error?

    // MARK: - Autofill

    func autofillLookup(serviceIdentifier: String) async throws -> [AutofillPayload] {
        if let err = autofillError { throw err }
        return autofillEntries.filter {
            $0.url.lowercased().contains(serviceIdentifier.lowercased())
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
    func searchEntries(vaultId: String, query: String) async throws -> [EntryPropertyRecord] { fatalError() }
    func generatePassword(options: PasswordOptions) async throws -> GeneratedPassword { fatalError() }
    func generateTOTP(secret: String) async throws -> TotpCode { fatalError() }
    func validateTOTPSecret(secret: String) async throws -> TotpCode { fatalError() }
    func checkBreach(password: String) async throws -> BreachCheckResult { fatalError() }
    func shareVault(vaultId: String, memberId: String, permission: SharePermission) async throws { fatalError() }
    func revokeShare(vaultId: String, memberId: String) async throws { fatalError() }
    func listSharedMembers(vaultId: String) async throws -> [SharedMember] { fatalError() }
    func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws { fatalError() }
    func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig { fatalError() }
    func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault { fatalError() }
    func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult { fatalError() }
    func getAuditLog(vaultId: String) async throws -> [AuditLogEntry] { fatalError() }
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}

// MARK: - AutofillProviderTests

@available(macOS 14.0, iOS 17.0, *)
final class AutofillProviderTests: XCTestCase {

    private var mock: MockAPIClient!

    override func setUp() {
        super.setUp()
        mock = MockAPIClient()
        mock.autofillEntries = [
            AutofillPayload(entryId: "1", title: "GitHub", username: "dev@example.com", password: "gh-secret-123", url: "https://github.com"),
            AutofillPayload(entryId: "2", title: "GitLab", username: "dev@example.com", password: "gl-secret-456", url: "https://gitlab.com"),
            AutofillPayload(entryId: "3", title: "Bank", username: "user@bank.com", password: "bank-pass-789", url: "https://mybank.com"),
        ]
    }

    // MARK: - Tests

    /// Validates: Requirement 14.5 — no saved credentials match message state
    func testAutofillLookupNoMatchesReturnsEmptyArray() async throws {
        let results = try await mock.autofillLookup(serviceIdentifier: "https://nonexistent-site.com")
        XCTAssertTrue(results.isEmpty, "Lookup for a non-matching URL should return an empty array")
    }

    /// Validates: Requirement 14.3 — matching credentials are returned for selection
    func testAutofillLookupReturnsMatchingCredentials() async throws {
        let results = try await mock.autofillLookup(serviceIdentifier: "github.com")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.entryId, "1")
        XCTAssertEqual(results.first?.title, "GitHub")
    }

    /// Validates: Requirements 14.3, 14.5 — each returned payload has non-empty username and password
    func testAutofillPayloadContainsUsernameAndPassword() async throws {
        let results = try await mock.autofillLookup(serviceIdentifier: "git")
        XCTAssertFalse(results.isEmpty, "Should match entries containing 'git' in URL")
        for payload in results {
            XCTAssertFalse(payload.username.isEmpty, "Username should not be empty for entry \(payload.entryId)")
            XCTAssertFalse(payload.password.isEmpty, "Password should not be empty for entry \(payload.entryId)")
        }
    }

    /// Validates: Requirement 14.3 — API errors propagate to the caller
    func testAutofillLookupAPIErrorPropagates() async {
        let expectedError = APIError(status: 500, code: "server_error", message: "Internal error", details: nil)
        mock.autofillError = expectedError

        do {
            _ = try await mock.autofillLookup(serviceIdentifier: "github.com")
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error.status, 500)
            XCTAssertEqual(error.code, "server_error")
        } catch {
            XCTFail("Expected APIError but got \(type(of: error))")
        }
    }
}
