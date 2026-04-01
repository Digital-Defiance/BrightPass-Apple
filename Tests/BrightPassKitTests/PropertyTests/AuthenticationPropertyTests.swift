// Property 28: Successful Authentication Stores JWT and Keys
// Validates: Requirements 20.3, 20.8
//
// For any valid 12-word BIP39 mnemonic, username, and JWT token string,
// after a successful direct challenge login, the JWT SHALL be stored in
// KeychainStore, the encrypted private key SHALL be stored, and
// isAuthenticated SHALL be true.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Generators

/// Picks 12 random words from the FallbackSDKWrapper BIP39 subset to form a valid mnemonic.
private let validMnemonicGen: Gen<String> = {
    let bip39Words = [
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
        "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
        "acoustic", "acquire", "across", "act", "action", "actor", "actress", "actual",
        "adapt", "add", "addict", "address", "adjust", "admit", "adult", "advance",
        "advice", "aerobic", "affair", "afford", "afraid", "again", "age", "agent",
        "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album",
        "alcohol", "alert", "alien", "all", "alley", "allow", "almost", "alone",
        "alpha", "already", "also", "alter", "always", "amateur", "amazing", "among",
        "amount", "amused", "analyst", "anchor", "ancient", "anger", "angle", "angry",
        "animal", "ankle", "announce", "annual", "another", "answer", "antenna", "antique",
        "anxiety", "any", "apart", "apology", "appear", "apple", "approve", "april",
        "arch", "arctic", "area", "arena", "argue", "arm", "armed", "armor",
        "army", "around", "arrange", "arrest", "arrive", "arrow", "art", "artefact",
        "artist", "artwork", "ask", "aspect", "assault", "asset", "assist", "assume",
        "asthma", "athlete", "atom", "attack", "attend", "attitude", "attract", "auction",
        "audit", "august", "aunt", "author", "auto", "autumn", "average", "avocado",
        "avoid", "awake", "aware", "away", "awesome", "awful", "awkward", "axis",
        "baby", "bachelor", "bacon", "badge", "bag", "balance", "balcony", "ball",
        "bamboo", "banana", "banner", "bar", "barely", "bargain", "barrel", "base",
        "basic", "basket", "battle", "beach", "bean", "beauty", "because", "become",
        "beef", "before", "begin", "behave", "behind", "believe", "below", "belt",
        "bench", "benefit", "best", "betray", "better", "between", "beyond", "bicycle",
        "bid", "bike", "bind", "biology", "bird", "birth", "bitter", "black",
        "blade", "blame", "blanket", "blast", "bleak", "bless", "blind", "blood",
        "blossom", "blouse", "blue", "blur", "blush", "board", "boat", "body"
    ]
    return Gen.compose { c in
        (0..<12).map { _ in bip39Words[abs(c.generate(using: Int.arbitrary)) % bip39Words.count] }
            .joined(separator: " ")
    }
}()

/// Short alphanumeric string for usernames and JWT tokens.
private let shortAlphaString: Gen<String> = Gen<Character>.fromElements(in: "a"..."z")
    .proliferate(withSize: 10)
    .suchThat { !$0.isEmpty }
    .map { String($0.prefix(max(1, Int.random(in: 3...10)))) }

/// Generates a valid hex string of 32 bytes (64 hex chars) for use as a challenge.
private let hexChallengeGen: Gen<String> = Gen.compose { c in
    (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
}

/// Generates a JWT-like token string (three dot-separated base64 segments).
private let jwtTokenGen: Gen<String> = Gen.compose { c in
    let seg1 = c.generate(using: shortAlphaString)
    let seg2 = c.generate(using: shortAlphaString)
    let seg3 = c.generate(using: shortAlphaString)
    return "\(seg1).\(seg2).\(seg3)"
}

// MARK: - Mock API Client

/// Mock API client that returns configurable DirectLoginChallenge and DirectChallengeResponse.
private final class MockAuthAPIClient: APIClientProtocol, @unchecked Sendable {
    var challengeToReturn: DirectLoginChallenge
    var responseToReturn: DirectChallengeResponse

    init(challenge: DirectLoginChallenge, response: DirectChallengeResponse) {
        self.challengeToReturn = challenge
        self.responseToReturn = response
    }

    func requestDirectLogin() async throws -> DirectLoginChallenge { challengeToReturn }
    func submitDirectChallenge(challenge: String, signature: String, username: String?, email: String?) async throws -> DirectChallengeResponse { responseToReturn }
    func refreshToken() async throws -> DirectChallengeResponse { fatalError() }
    func logout() async throws { /* no-op success */ }
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

// MARK: - Mock Keyring (passthrough encryption)

/// Simple passthrough keyring that prepends a marker byte so encrypt/decrypt round-trips.
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

// MARK: - Property Tests

/// **Validates: Requirements 20.3, 20.8**
@available(macOS 14.0, iOS 17.0, *)
final class AuthenticationPropertyTests: XCTestCase {

    /// **Property 28: Successful Authentication Stores JWT and Keys**
    ///
    /// For any valid mnemonic, username, and JWT token, after `login()`:
    /// - `isAuthenticated` is true
    /// - `KeychainStore.loadJWT()` returns the expected JWT
    /// - `KeychainStore.loadEncryptedPrivateKey(memberId:)` returns non-nil data
    ///
    /// Uses manual iteration with `@MainActor` async to avoid SwiftCheck + semaphore deadlock.
    @MainActor
    func testSuccessfulAuthenticationStoresJWTAndKeys() async {
        let keychain = MockKeychainStore()
        let sdkWrapper = FallbackSDKWrapper()
        let mockKeyring = MockKeyring()

        for i in 0..<50 {
            keychain.reset()

            let mnemonicPhrase = validMnemonicGen.generate
            let username = shortAlphaString.generate
            let jwtToken = jwtTokenGen.generate

            // Derive the expected memberId so we can verify key storage
            guard let member = sdkWrapper.loginWithMnemonic(mnemonicPhrase, name: username, email: username) else {
                XCTFail("Iteration \(i): FallbackSDKWrapper failed to derive keys from mnemonic: \(mnemonicPhrase)")
                continue
            }

            let challenge = DirectLoginChallenge(
                challenge: hexChallengeGen.generate,
                message: "Please sign",
                serverPublicKey: "server-pub-key-hex"
            )

            let profile = UserProfile(
                id: member.id,
                username: username,
                email: "\(username)@test.com",
                roles: [UserRole(_id: "role-\(member.id)", name: "User", admin: false, member: true, child: false, system: false)],
                emailVerified: true,
                timezone: "UTC",
                siteLanguage: "en",
                darkMode: false,
                currency: "USD",
                directChallenge: true,
                lastLogin: nil
            )

            let response = DirectChallengeResponse(
                message: "OK",
                user: profile,
                token: jwtToken,
                serverPublicKey: "server-pub-key-hex"
            )

            let apiClient = MockAuthAPIClient(challenge: challenge, response: response)

            let vm = AuthViewModel(
                apiClient: apiClient,
                keychain: keychain,
                sdkWrapper: sdkWrapper,
                keyring: mockKeyring
            )
            vm.username = username
            vm.mnemonic = mnemonicPhrase

            await vm.login()

            XCTAssertTrue(vm.isAuthenticated, "Iteration \(i): isAuthenticated should be true after successful login")
            XCTAssertNil(vm.error, "Iteration \(i): error should be nil after successful login, got: \(String(describing: vm.error))")

            let storedJWT = try? keychain.loadJWT()
            XCTAssertEqual(storedJWT, jwtToken, "Iteration \(i): stored JWT should match the token from the API response")

            let storedKey = try? keychain.loadEncryptedPrivateKey(memberId: member.id)
            XCTAssertNotNil(storedKey, "Iteration \(i): encrypted private key should be stored for memberId \(member.id)")
        }
    }

    /// **Property 29: Logout Clears JWT, Keys, and Resets Navigation**
    /// **Validates: Requirements 20.5**
    ///
    /// For any authenticated session (valid mnemonic, username, JWT), after `logout()`:
    /// - `isAuthenticated` is false
    /// - `KeychainStore.loadJWT()` returns nil
    /// - `KeychainStore.loadEncryptedPrivateKey(memberId:)` returns nil
    /// - `userProfile` is nil, `username` and `mnemonic` are empty
    ///
    /// Uses manual iteration with `@MainActor` async to avoid SwiftCheck + semaphore deadlock.
    @MainActor
    func testLogoutClearsJWTKeysAndState() async {
        let keychain = MockKeychainStore()
        let sdkWrapper = FallbackSDKWrapper()
        let mockKeyring = MockKeyring()

        for i in 0..<50 {
            keychain.reset()

            let mnemonicPhrase = validMnemonicGen.generate
            let username = shortAlphaString.generate
            let jwtToken = jwtTokenGen.generate

            // Derive memberId for key storage verification
            guard let member = sdkWrapper.loginWithMnemonic(mnemonicPhrase, name: username, email: username) else {
                XCTFail("Iteration \(i): FallbackSDKWrapper failed to derive keys from mnemonic")
                continue
            }

            let challenge = DirectLoginChallenge(
                challenge: hexChallengeGen.generate,
                message: "Please sign",
                serverPublicKey: "server-pub-key-hex"
            )

            let profile = UserProfile(
                id: member.id,
                username: username,
                email: "\(username)@test.com",
                roles: [UserRole(_id: "role-\(member.id)", name: "User", admin: false, member: true, child: false, system: false)],
                emailVerified: true,
                timezone: "UTC",
                siteLanguage: "en",
                darkMode: false,
                currency: "USD",
                directChallenge: true,
                lastLogin: nil
            )

            let response = DirectChallengeResponse(
                message: "OK",
                user: profile,
                token: jwtToken,
                serverPublicKey: "server-pub-key-hex"
            )

            let apiClient = MockAuthAPIClient(challenge: challenge, response: response)

            let vm = AuthViewModel(
                apiClient: apiClient,
                keychain: keychain,
                sdkWrapper: sdkWrapper,
                keyring: mockKeyring
            )
            vm.username = username
            vm.mnemonic = mnemonicPhrase

            // First login to populate state
            await vm.login()
            XCTAssertTrue(vm.isAuthenticated, "Iteration \(i): precondition — should be authenticated after login")

            // Now logout
            await vm.logout()

            // Assert all auth state is cleared
            XCTAssertFalse(vm.isAuthenticated, "Iteration \(i): isAuthenticated should be false after logout")
            XCTAssertNil(vm.userProfile, "Iteration \(i): userProfile should be nil after logout")
            XCTAssertEqual(vm.username, "", "Iteration \(i): username should be empty after logout")
            XCTAssertEqual(vm.mnemonic, "", "Iteration \(i): mnemonic should be empty after logout")

            // Assert JWT is cleared from keychain
            let storedJWT = try? keychain.loadJWT()
            XCTAssertNil(storedJWT, "Iteration \(i): JWT should be nil in keychain after logout")

            // Assert encrypted private key is cleared from keychain
            let storedKey = try? keychain.loadEncryptedPrivateKey(memberId: member.id)
            XCTAssertNil(storedKey, "Iteration \(i): encrypted private key should be nil after logout for memberId \(member.id)")
        }
    }
}
