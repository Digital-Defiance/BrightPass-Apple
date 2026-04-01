// Unit tests for authentication and registration
// Validates: Requirements 20.2, 20.3, 20.4, 20.5, 20.6, 20.7, 21.3, 21.4, 21.5, 21.7

import XCTest
@testable import BrightPassKit

// MARK: - Mock API Client

@available(macOS 14.0, iOS 17.0, *)
private final class AuthRegMockAPIClient: APIClientProtocol, @unchecked Sendable {

    // Direct challenge login
    var challengeToReturn: DirectLoginChallenge?
    var challengeError: Error?
    var challengeResponseToReturn: DirectChallengeResponse?
    var challengeResponseError: Error?

    // Refresh token
    var refreshResponseToReturn: DirectChallengeResponse?
    var refreshError: Error?

    // Registration
    var registerResponseToReturn: AuthResponse?
    var registerError: Error?

    // Tracking
    var logoutCalled = false

    // MARK: - Auth

    func requestDirectLogin() async throws -> DirectLoginChallenge {
        if let err = challengeError { throw err }
        guard let c = challengeToReturn else {
            throw APIError(status: 500, code: "no_mock", message: "No mock challenge", details: nil)
        }
        return c
    }

    func submitDirectChallenge(challenge: String, signature: String, username: String?, email: String?) async throws -> DirectChallengeResponse {
        if let err = challengeResponseError { throw err }
        guard let r = challengeResponseToReturn else {
            throw APIError(status: 500, code: "no_mock", message: "No mock response", details: nil)
        }
        return r
    }

    func refreshToken() async throws -> DirectChallengeResponse {
        if let err = refreshError { throw err }
        guard let r = refreshResponseToReturn else {
            throw APIError(status: 500, code: "no_mock", message: "No mock refresh", details: nil)
        }
        return r
    }

    func logout() async throws {
        logoutCalled = true
    }

    func register(username: String, email: String, password: String) async throws -> AuthResponse {
        if let err = registerError { throw err }
        guard let r = registerResponseToReturn else {
            throw APIError(status: 500, code: "no_mock", message: "No mock register", details: nil)
        }
        return r
    }

    // MARK: - Unused stubs
    func verifyToken() async throws -> UserProfile { fatalError() }
    func login(username: String, password: String) async throws -> AuthResponse { fatalError() }
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

// MARK: - Mock Keyring (passthrough encryption)

private final class MockKeyring: KeyringProtocol, @unchecked Sendable {
    private let marker: UInt8 = 0xAB

    func encrypt(data: Data) throws -> Data {
        var result = Data([marker])
        result.append(data)
        return result
    }

    func decrypt(encryptedData: Data) throws -> Data {
        guard encryptedData.first == marker else {
            throw SimpleKeyringError.encryptionFailed
        }
        return encryptedData.dropFirst()
    }

    func deleteKey() throws {}
    func hasKey() -> Bool { true }
}

// MARK: - Test Helpers

private let validMnemonic = "abandon ability able about above absent absorb abstract absurd abuse access accident"

@available(macOS 14.0, iOS 17.0, *)
private func makeTestProfile(username: String = "testuser", memberId: String = "member123") -> UserProfile {
    UserProfile(
        id: memberId,
        username: username,
        email: "\(username)@test.com",
        roles: [UserRole(_id: "role-\(memberId)", name: "User", admin: false, member: true, child: false, system: false)],
        emailVerified: true,
        timezone: "UTC",
        siteLanguage: "en",
        darkMode: false,
        currency: "USD",
        directChallenge: true,
        lastLogin: nil
    )
}

@available(macOS 14.0, iOS 17.0, *)
private func makeTestChallenge() -> DirectLoginChallenge {
    DirectLoginChallenge(
        challenge: "aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233",
        message: "Please sign",
        serverPublicKey: "server-pub-key-hex"
    )
}

@available(macOS 14.0, iOS 17.0, *)
private func makeTestChallengeResponse(token: String = "jwt.token.here", username: String = "testuser", memberId: String = "member123") -> DirectChallengeResponse {
    DirectChallengeResponse(
        message: "OK",
        user: makeTestProfile(username: username, memberId: memberId),
        token: token,
        serverPublicKey: "server-pub-key-hex"
    )
}


// MARK: - AuthViewModel Tests

/// Tests for AuthViewModel: login, logout, mnemonic validation, token refresh, session expiry.
/// Validates: Requirements 20.2, 20.3, 20.4, 20.5, 20.6, 20.7
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class AuthViewModelTests: XCTestCase {

    private var mock: AuthRegMockAPIClient!
    private var keychain: MockKeychainStore!
    private var sdkWrapper: FallbackSDKWrapper!
    private var keyring: MockKeyring!

    override func setUp() {
        super.setUp()
        mock = AuthRegMockAPIClient()
        keychain = MockKeychainStore()
        sdkWrapper = FallbackSDKWrapper()
        keyring = MockKeyring()
    }

    // MARK: - 1. Direct Challenge Login Flow (Req 20.2, 20.3)

    /// Full login: mnemonic validation → key derivation → challenge request → signing → submission → JWT storage
    func testDirectChallengeLoginFlowSuccess() async {
        // Derive member to get the expected memberId
        let member = sdkWrapper.loginWithMnemonic(validMnemonic, name: "testuser", email: "testuser")!

        let profile = makeTestProfile(username: "testuser", memberId: member.id)
        mock.challengeToReturn = makeTestChallenge()
        mock.challengeResponseToReturn = DirectChallengeResponse(
            message: "OK", user: profile, token: "jwt.test.token", serverPublicKey: "server-pub-key-hex"
        )

        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = "testuser"
        vm.mnemonic = validMnemonic

        await vm.login()

        // Verify authenticated state
        XCTAssertTrue(vm.isAuthenticated)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.userProfile?.id, member.id)

        // Verify JWT stored
        let storedJWT = try? keychain.loadJWT()
        XCTAssertEqual(storedJWT, "jwt.test.token")

        // Verify encrypted private key stored
        let storedKey = try? keychain.loadEncryptedPrivateKey(memberId: member.id)
        XCTAssertNotNil(storedKey)
    }

    // MARK: - 2. Login Failure Displays Error (Req 20.4)

    /// Login failure from API sets error and allows retry.
    func testLoginFailureDisplaysError() async {
        mock.challengeToReturn = makeTestChallenge()
        mock.challengeResponseError = APIError(
            status: 401, code: "invalid_signature", message: "Invalid signature", details: nil
        )

        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = "testuser"
        vm.mnemonic = validMnemonic

        await vm.login()

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)

        // JWT should NOT be stored
        let storedJWT = try? keychain.loadJWT()
        XCTAssertNil(storedJWT)
    }

    /// Login with invalid mnemonic sets validation error without API call.
    func testLoginWithInvalidMnemonicSetsError() async {
        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = "testuser"
        vm.mnemonic = "invalid mnemonic phrase"

        await vm.login()

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNotNil(vm.error)
    }

    // MARK: - 3. Logout Clears State (Req 20.5)

    /// Logout clears JWT, encrypted private key, and resets navigation state.
    func testLogoutClearsJWTAndEncryptedKeyAndResetsState() async {
        let member = sdkWrapper.loginWithMnemonic(validMnemonic, name: "testuser", email: "testuser")!
        let profile = makeTestProfile(username: "testuser", memberId: member.id)

        mock.challengeToReturn = makeTestChallenge()
        mock.challengeResponseToReturn = DirectChallengeResponse(
            message: "OK", user: profile, token: "jwt.test.token", serverPublicKey: "server-pub-key-hex"
        )

        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = "testuser"
        vm.mnemonic = validMnemonic

        // Login first
        await vm.login()
        XCTAssertTrue(vm.isAuthenticated)

        // Now logout
        await vm.logout()

        // Verify state cleared
        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNil(vm.userProfile)
        XCTAssertEqual(vm.username, "")
        XCTAssertEqual(vm.mnemonic, "")

        // Verify keychain cleared
        let storedJWT = try? keychain.loadJWT()
        XCTAssertNil(storedJWT)
        let storedKey = try? keychain.loadEncryptedPrivateKey(memberId: member.id)
        XCTAssertNil(storedKey)
    }

    // MARK: - 6. Session Expired Notification (Req 20.6)

    /// 401 notification triggers logout flow: sets isAuthenticated=false.
    func testSessionExpiredNotificationSetsIsAuthenticatedFalse() async {
        // Pre-populate keychain with a JWT so AuthViewModel starts authenticated
        try! keychain.saveJWT("existing.jwt.token")

        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        XCTAssertTrue(vm.isAuthenticated)

        // Post the session expired notification
        NotificationCenter.default.post(name: .sessionExpired, object: nil)

        // Give the notification handler time to execute on main actor
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertEqual(vm.error, .sessionExpired)
    }

    // MARK: - 7. Mnemonic Validation (Req 20.7)

    /// Valid 12-word BIP39 mnemonic passes validation.
    func testMnemonicValidationAcceptsValidPhrase() {
        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.mnemonic = validMnemonic
        vm.validateMnemonic()
        XCTAssertTrue(vm.isMnemonicValid)
    }

    /// Invalid mnemonic (wrong word count) fails validation.
    func testMnemonicValidationRejectsWrongWordCount() {
        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.mnemonic = "abandon ability able"
        vm.validateMnemonic()
        XCTAssertFalse(vm.isMnemonicValid)
    }

    /// Invalid mnemonic (non-BIP39 words) fails validation.
    func testMnemonicValidationRejectsNonBIP39Words() {
        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.mnemonic = "hello world foo bar baz qux quux corge grault garply waldo fred"
        vm.validateMnemonic()
        XCTAssertFalse(vm.isMnemonicValid)
    }

    /// Empty mnemonic fails validation.
    func testMnemonicValidationRejectsEmptyString() {
        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.mnemonic = ""
        vm.validateMnemonic()
        XCTAssertFalse(vm.isMnemonicValid)
    }

    // MARK: - 8. Token Refresh Flow (Req 20.9)

    /// Successful token refresh updates JWT in keychain.
    func testRefreshTokenSuccess() async {
        try! keychain.saveJWT("old.jwt.token")

        let profile = makeTestProfile()
        mock.refreshResponseToReturn = DirectChallengeResponse(
            message: "OK", user: profile, token: "new.jwt.token", serverPublicKey: "server-pub-key-hex"
        )

        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        XCTAssertTrue(vm.isAuthenticated)

        await vm.refreshTokenIfNeeded()

        let storedJWT = try? keychain.loadJWT()
        XCTAssertEqual(storedJWT, "new.jwt.token")
        XCTAssertTrue(vm.isAuthenticated)
        XCTAssertEqual(vm.userProfile?.username, "testuser")
    }

    /// Failed token refresh sets isAuthenticated to false.
    func testRefreshTokenFailureSetsUnauthenticated() async {
        try! keychain.saveJWT("old.jwt.token")

        mock.refreshError = APIError(
            status: 401, code: "expired", message: "Token expired", details: nil
        )

        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        XCTAssertTrue(vm.isAuthenticated)

        await vm.refreshTokenIfNeeded()

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNotNil(vm.error)
    }

    /// Refresh does nothing when not authenticated.
    func testRefreshTokenSkipsWhenNotAuthenticated() async {
        let vm = AuthViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        XCTAssertFalse(vm.isAuthenticated)

        await vm.refreshTokenIfNeeded()

        // Should remain unauthenticated, no error
        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNil(vm.error)
    }
}


// MARK: - RegistrationViewModel Tests

/// Tests for RegistrationViewModel: registration, field validation, mnemonic generation, confirmation.
/// Validates: Requirements 21.3, 21.4, 21.5, 21.7
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class RegistrationViewModelTests: XCTestCase {

    private var mock: AuthRegMockAPIClient!
    private var keychain: MockKeychainStore!
    private var sdkWrapper: FallbackSDKWrapper!
    private var keyring: MockKeyring!

    override func setUp() {
        super.setUp()
        mock = AuthRegMockAPIClient()
        keychain = MockKeychainStore()
        sdkWrapper = FallbackSDKWrapper()
        keyring = MockKeyring()
    }

    // MARK: - 4. Mismatched Passwords (Req 21.5)

    /// Registration with mismatched passwords shows field error without API call.
    func testRegistrationMismatchedPasswordsShowsFieldError() async {
        let vm = RegistrationViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = "newuser"
        vm.email = "newuser@test.com"
        vm.password = "StrongPass123!"
        vm.confirmPassword = "DifferentPass456!"

        await vm.register()

        XCTAssertNotNil(vm.fieldErrors["confirmPassword"])
        XCTAssertEqual(vm.fieldErrors["confirmPassword"], "Passwords do not match")
        XCTAssertNil(vm.generatedMnemonic, "Mnemonic should not be generated when validation fails")
        XCTAssertFalse(vm.isRegistered)
    }

    /// Registration with empty username shows field error.
    func testRegistrationEmptyUsernameShowsFieldError() async {
        let vm = RegistrationViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = ""
        vm.email = "user@test.com"
        vm.password = "pass"
        vm.confirmPassword = "pass"

        await vm.register()

        XCTAssertNotNil(vm.fieldErrors["username"])
    }

    /// Registration with empty email shows field error.
    func testRegistrationEmptyEmailShowsFieldError() async {
        let vm = RegistrationViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = "user"
        vm.email = ""
        vm.password = "pass"
        vm.confirmPassword = "pass"

        await vm.register()

        XCTAssertNotNil(vm.fieldErrors["email"])
    }

    // MARK: - 5. Registration Success (Req 21.3, 21.4, 21.7)

    /// Successful registration generates mnemonic and requires confirmation before storing credentials.
    func testRegistrationSuccessGeneratesMnemonicAndRequiresConfirmation() async {
        mock.registerResponseToReturn = AuthResponse(
            message: "OK",
            data: AuthResponseData(token: "reg.jwt.token", memberId: "new-member-id", energyBalance: 100)
        )

        let vm = RegistrationViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = "newuser"
        vm.email = "newuser@test.com"
        vm.password = "StrongPass123!"
        vm.confirmPassword = "StrongPass123!"

        await vm.register()

        // Mnemonic should be generated
        XCTAssertNotNil(vm.generatedMnemonic)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)

        // JWT should NOT be stored yet (waiting for mnemonic confirmation)
        let storedJWT = try? keychain.loadJWT()
        XCTAssertNil(storedJWT, "JWT should not be stored before mnemonic confirmation")
        XCTAssertFalse(vm.hasSavedMnemonic)
        XCTAssertFalse(vm.isRegistered)
    }

    /// After registration, confirmMnemonicSaved stores JWT and encrypted key.
    func testConfirmMnemonicSavedStoresCredentials() async {
        mock.registerResponseToReturn = AuthResponse(
            message: "OK",
            data: AuthResponseData(token: "reg.jwt.token", memberId: "new-member-id", energyBalance: 100)
        )

        let vm = RegistrationViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = "newuser"
        vm.email = "newuser@test.com"
        vm.password = "StrongPass123!"
        vm.confirmPassword = "StrongPass123!"

        await vm.register()
        XCTAssertNotNil(vm.generatedMnemonic)

        // Now confirm mnemonic saved
        vm.confirmMnemonicSaved()

        XCTAssertTrue(vm.hasSavedMnemonic)
        XCTAssertTrue(vm.isRegistered)

        // JWT should now be stored
        let storedJWT = try? keychain.loadJWT()
        XCTAssertEqual(storedJWT, "reg.jwt.token")
    }

    /// Registration API failure sets error.
    func testRegistrationAPIFailureSetsError() async {
        mock.registerError = APIError(
            status: 400, code: "duplicate", message: "Username already exists", details: ["Username already exists"]
        )

        let vm = RegistrationViewModel(apiClient: mock, keychain: keychain, sdkWrapper: sdkWrapper, keyring: keyring)
        vm.username = "existinguser"
        vm.email = "existing@test.com"
        vm.password = "StrongPass123!"
        vm.confirmPassword = "StrongPass123!"

        await vm.register()

        XCTAssertNotNil(vm.error)
        XCTAssertNil(vm.generatedMnemonic)
        XCTAssertFalse(vm.isLoading)
    }
}
