// Unit tests for password generator, TOTP, and breach check
// Validates: Requirements 5.2, 6.1, 6.2, 7.3, 7.4, 7.5

import XCTest
@testable import BrightPassKit

// MARK: - Mock APIClient for Password Generator, TOTP, and Breach Check Tests

@available(macOS 14.0, iOS 17.0, *)
private final class PwdTOTPBreachMockAPIClient: APIClientProtocol, @unchecked Sendable {

    // Password generation
    var passwordToReturn: GeneratedPassword?
    var passwordError: Error?

    // TOTP
    var totpToReturn: TotpCode?
    var totpError: Error?

    // Breach check
    var breachResultToReturn: BreachCheckResult?
    var breachError: Error?

    func generatePassword(options: PasswordOptions) async throws -> GeneratedPassword {
        if let err = passwordError { throw err }
        guard let pw = passwordToReturn else {
            throw APIError(status: 500, code: "no_mock", message: "No mock password configured", details: nil)
        }
        return pw
    }

    func generateTOTP(secret: String) async throws -> TotpCode {
        if let err = totpError { throw err }
        guard let code = totpToReturn else {
            throw APIError(status: 500, code: "no_mock", message: "No mock TOTP configured", details: nil)
        }
        return code
    }

    func validateTOTPSecret(secret: String) async throws -> TotpCode {
        if let err = totpError { throw err }
        guard let code = totpToReturn else {
            throw APIError(status: 500, code: "no_mock", message: "No mock TOTP configured", details: nil)
        }
        return code
    }

    func checkBreach(password: String) async throws -> BreachCheckResult {
        if let err = breachError { throw err }
        guard let result = breachResultToReturn else {
            throw APIError(status: 500, code: "no_mock", message: "No mock breach result configured", details: nil)
        }
        return result
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


// MARK: - PasswordGeneratorViewModel Tests

/// Tests for PasswordGeneratorViewModel length clamping, options building, and generate flow.
/// Validates: Requirements 5.2
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class PasswordGeneratorViewModelTests: XCTestCase {

    private var mock: PwdTOTPBreachMockAPIClient!
    private var vm: PasswordGeneratorViewModel!

    override func setUp() {
        super.setUp()
        mock = PwdTOTPBreachMockAPIClient()
        vm = PasswordGeneratorViewModel(apiClient: mock)
    }

    // MARK: - Length Clamping

    /// Req 5.2: Setting length below 8 clamps to 8.
    func testLengthBelowMinimumClampsTo8() {
        vm.length = 3
        XCTAssertEqual(vm.length, 8)

        vm.length = 0
        XCTAssertEqual(vm.length, 8)

        vm.length = -1
        XCTAssertEqual(vm.length, 8)
    }

    /// Req 5.2: Setting length above 128 clamps to 128.
    func testLengthAboveMaximumClampsTo128() {
        vm.length = 200
        XCTAssertEqual(vm.length, 128)

        vm.length = 999
        XCTAssertEqual(vm.length, 128)
    }

    /// Req 5.2: Values within range are preserved.
    func testLengthWithinRangePreserved() {
        vm.length = 8
        XCTAssertEqual(vm.length, 8)

        vm.length = 20
        XCTAssertEqual(vm.length, 20)

        vm.length = 128
        XCTAssertEqual(vm.length, 128)

        vm.length = 64
        XCTAssertEqual(vm.length, 64)
    }

    // MARK: - Generate

    /// Req 5.2: Successful generate sets generatedPassword, clears error, isLoading is false.
    func testGenerateSuccess() async {
        mock.passwordToReturn = GeneratedPassword(password: "Str0ng!Pass", strength: "strong")

        await vm.generate()

        XCTAssertEqual(vm.generatedPassword, "Str0ng!Pass")
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    /// Req 5.2: Failed generate sets error, generatedPassword stays nil, isLoading is false.
    func testGenerateFailure() async {
        mock.passwordError = APIError(status: 500, code: "server_error", message: "Generation failed", details: nil)

        await vm.generate()

        XCTAssertNil(vm.generatedPassword)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - All Toggles Off

    /// Edge case: all toggles off reflects in options.
    func testAllTogglesOffEdgeCase() {
        vm.includeUppercase = false
        vm.includeLowercase = false
        vm.includeDigits = false
        vm.includeSpecial = false

        let opts = vm.options
        XCTAssertFalse(opts.includeUppercase)
        XCTAssertFalse(opts.includeLowercase)
        XCTAssertFalse(opts.includeDigits)
        XCTAssertFalse(opts.includeSpecial)
    }

    // MARK: - Options Computed Property

    /// Verify options computed property correctly builds PasswordOptions from current state.
    func testOptionsComputedPropertyBuildsCorrectly() {
        vm.length = 32
        vm.includeUppercase = true
        vm.includeLowercase = false
        vm.includeDigits = true
        vm.includeSpecial = false
        vm.minUppercase = 2
        vm.minDigits = 3
        vm.minSpecial = 0

        let opts = vm.options
        XCTAssertEqual(opts.length, 32)
        XCTAssertTrue(opts.includeUppercase)
        XCTAssertFalse(opts.includeLowercase)
        XCTAssertTrue(opts.includeDigits)
        XCTAssertFalse(opts.includeSpecial)
        XCTAssertEqual(opts.minUppercase, 2)
        XCTAssertEqual(opts.minDigits, 3)
        XCTAssertEqual(opts.minSpecial, 0)
    }
}


// MARK: - TOTPViewModel Tests

/// Tests for TOTPViewModel code generation, stop, and copy flows.
/// Validates: Requirements 6.1, 6.2
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class TOTPViewModelTests: XCTestCase {

    private var mock: PwdTOTPBreachMockAPIClient!
    private var vm: TOTPViewModel!

    override func setUp() {
        super.setUp()
        mock = PwdTOTPBreachMockAPIClient()
        vm = TOTPViewModel(apiClient: mock)
    }

    override func tearDown() {
        vm.stopCodeGeneration()
        super.tearDown()
    }

    // MARK: - startCodeGeneration

    /// Req 6.1: Successful code generation sets currentCode and remainingSeconds.
    func testStartCodeGenerationSuccess() async {
        mock.totpToReturn = TotpCode(code: "123456", remainingSeconds: 25, period: 30)

        await vm.startCodeGeneration(secret: "JBSWY3DPEHPK3PXP")

        XCTAssertEqual(vm.currentCode, "123456")
        XCTAssertEqual(vm.remainingSeconds, 25)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    /// Req 6.1: Failed code generation (invalid secret) sets error, currentCode stays nil.
    func testStartCodeGenerationFailure() async {
        mock.totpError = APIError(status: 400, code: "invalid_secret", message: "Invalid TOTP secret", details: nil)

        await vm.startCodeGeneration(secret: "INVALID")

        XCTAssertNil(vm.currentCode)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - stopCodeGeneration

    /// Req 6.2: Stopping code generation keeps the last code value.
    func testStopCodeGenerationKeepsLastCode() async {
        mock.totpToReturn = TotpCode(code: "654321", remainingSeconds: 20, period: 30)

        await vm.startCodeGeneration(secret: "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(vm.currentCode, "654321")

        vm.stopCodeGeneration()

        // currentCode should remain at the last fetched value
        XCTAssertEqual(vm.currentCode, "654321")
    }

    // MARK: - copyCode

    /// Req 6.1: copyCode returns the current code value.
    func testCopyCodeReturnsCurrentCode() async {
        mock.totpToReturn = TotpCode(code: "111222", remainingSeconds: 15, period: 30)

        await vm.startCodeGeneration(secret: "JBSWY3DPEHPK3PXP")

        let copied = vm.copyCode()
        XCTAssertEqual(copied, "111222")
    }

    /// copyCode returns nil when no code has been generated.
    func testCopyCodeReturnsNilWhenNoCode() {
        let copied = vm.copyCode()
        XCTAssertNil(copied)
    }
}


// MARK: - BreachCheckViewModel Tests

/// Tests for BreachCheckViewModel breach check flows and loading states.
/// Validates: Requirements 7.3, 7.4, 7.5
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class BreachCheckViewModelTests: XCTestCase {

    private var mock: PwdTOTPBreachMockAPIClient!
    private var vm: BreachCheckViewModel!

    override func setUp() {
        super.setUp()
        mock = PwdTOTPBreachMockAPIClient()
        vm = BreachCheckViewModel(apiClient: mock)
    }

    // MARK: - Breached Password

    /// Req 7.3: Breached password sets result.breached to true with breachCount.
    func testCheckPasswordBreached() async {
        mock.breachResultToReturn = BreachCheckResult(breached: true, breachCount: 42)

        await vm.checkPassword("password123")

        XCTAssertNotNil(vm.result)
        XCTAssertTrue(vm.result!.breached)
        XCTAssertEqual(vm.result!.breachCount, 42)
        XCTAssertNil(vm.error)
    }

    // MARK: - Safe Password

    /// Req 7.4: Safe password sets result.breached to false.
    func testCheckPasswordSafe() async {
        mock.breachResultToReturn = BreachCheckResult(breached: false, breachCount: nil)

        await vm.checkPassword("v3ry$ecure&Un1que!")

        XCTAssertNotNil(vm.result)
        XCTAssertFalse(vm.result!.breached)
        XCTAssertNil(vm.error)
    }

    // MARK: - Failure

    /// Req 7.5: Failed check sets error, result stays nil.
    func testCheckPasswordFailure() async {
        mock.breachError = APIError(status: 500, code: "server_error", message: "Service unavailable", details: nil)

        await vm.checkPassword("anypassword")

        XCTAssertNil(vm.result)
        XCTAssertNotNil(vm.error)
    }

    // MARK: - Loading State

    /// Req 7.5: isLoading is false after successful check.
    func testIsLoadingFalseAfterSuccess() async {
        mock.breachResultToReturn = BreachCheckResult(breached: false, breachCount: nil)

        await vm.checkPassword("test")

        XCTAssertFalse(vm.isLoading)
    }

    /// Req 7.5: isLoading is false after failed check.
    func testIsLoadingFalseAfterFailure() async {
        mock.breachError = APIError(status: 503, code: "unavailable", message: "Down", details: nil)

        await vm.checkPassword("test")

        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - Clears Previous Result

    /// Calling checkPassword clears previous result before making new request.
    func testCheckPasswordClearsPreviousResult() async {
        // First check: breached
        mock.breachResultToReturn = BreachCheckResult(breached: true, breachCount: 10)
        await vm.checkPassword("weak")
        XCTAssertNotNil(vm.result)
        XCTAssertTrue(vm.result!.breached)

        // Second check: safe — previous result should be cleared
        mock.breachResultToReturn = BreachCheckResult(breached: false, breachCount: nil)
        await vm.checkPassword("strong")
        XCTAssertNotNil(vm.result)
        XCTAssertFalse(vm.result!.breached)
    }
}
