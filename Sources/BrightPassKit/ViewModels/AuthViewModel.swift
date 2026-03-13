import Foundation
import CryptoKit

/// Manages authentication state: login via ECIES direct challenge, logout, token refresh.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class AuthViewModel {

    public var username: String = ""
    public var mnemonic: String = ""
    public var isLoading: Bool = false
    public var error: AppError?
    public var isAuthenticated: Bool = false
    public var isMnemonicValid: Bool = false
    public var userProfile: UserProfile?

    private let apiClient: APIClientProtocol
    private let keychain: KeychainStoreProtocol
    private let sdkWrapper: SDKWrapperProtocol
    private let keyring: KeyringProtocol
    private var sessionObserver: Any?

    public init(apiClient: APIClientProtocol,
                keychain: KeychainStoreProtocol,
                sdkWrapper: SDKWrapperProtocol = FallbackSDKWrapper(),
                keyring: KeyringProtocol = SimpleKeyring()) {
        self.apiClient = apiClient
        self.keychain = keychain
        self.sdkWrapper = sdkWrapper
        self.keyring = keyring

        // Check for existing JWT on init
        if let _ = try? keychain.loadJWT() {
            isAuthenticated = true
        }

        // Observe session expiry
        sessionObserver = NotificationCenter.default.addObserver(
            forName: .sessionExpired, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isAuthenticated = false
                self?.userProfile = nil
                self?.error = .sessionExpired
            }
        }
    }

    deinit {
        // sessionObserver cleanup handled by NotificationCenter's weak reference
    }

    // MARK: - Mnemonic Validation

    public func validateMnemonic() {
        isMnemonicValid = sdkWrapper.validateMnemonic(mnemonic)
    }

    // MARK: - Email Detection

    /// Validates whether the given string is a well-formed email address
    /// using `NSDataDetector` with the `.link` checking type (RFC 5322).
    private static func isValidEmail(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let range = NSRange(string.startIndex..., in: string)
        let matches = detector.matches(in: string, options: [], range: range)
        // Must be exactly one match covering the entire string, with a mailto: scheme
        guard matches.count == 1,
              let match = matches.first,
              match.range == range,
              match.url?.scheme == "mailto" else {
            return false
        }
        return true
    }

    // MARK: - Login (ECIES Direct Challenge Flow)

    /// Full ECIES direct challenge login:
    /// 1. Validate mnemonic → derive keys
    /// 2. POST request-direct-login → get challenge
    /// 3. SHA256 hash challenge → sign with private key
    /// 4. POST direct-challenge → get JWT + profile
    /// 5. Store JWT + encrypted private key
    public func login() async {
        let trimmed = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sdkWrapper.validateMnemonic(trimmed) else {
            error = .validationError(messages: ["Invalid mnemonic phrase."])
            return
        }

        let identifier = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let identifierIsEmail = Self.isValidEmail(identifier)

        guard let member = sdkWrapper.loginWithMnemonic(
            trimmed,
            name: identifierIsEmail ? identifier : identifier,
            email: identifierIsEmail ? identifier : identifier
        ) else {
            error = .validationError(messages: ["Failed to derive keys from mnemonic."])
            return
        }

        print("[Auth] Derived memberId: \(member.id)")
        print("[Auth] Derived publicKey: \(member.publicKey.map { String(format: "%02x", $0) }.joined())")

        isLoading = true
        error = nil

        do {
            // Step 1: Request challenge from server
            let challenge = try await apiClient.requestDirectLogin()

            // Step 2: Hex-decode the challenge and sign the raw bytes
            // The secp256k1 library hashes internally (SHA256) before signing,
            // matching the server's secp256k1.verify which also hashes internally.
            guard let challengeData = Data(hexString: challenge.challenge) else {
                throw AppError.validationError(messages: ["Invalid challenge data"])
            }

            guard let signature = sdkWrapper.signData(challengeData, withPrivateKey: member.privateKey) else {
                throw AppError.validationError(messages: ["Failed to sign challenge"])
            }

            // Step 3: Submit signed challenge with the correct identifier field
            let response = try await apiClient.submitDirectChallenge(
                challenge: challenge.challenge,
                signature: signature.map { String(format: "%02x", $0) }.joined(),
                username: identifierIsEmail ? nil : identifier,
                email: identifierIsEmail ? identifier : nil
            )

            // Step 4: Store JWT
            try keychain.saveJWT(response.token)

            // Step 5: Encrypt and store private key
            let encryptedKey = try keyring.encrypt(data: member.privateKey)
            try keychain.saveEncryptedPrivateKey(encryptedKey, memberId: member.id)

            userProfile = response.user
            isAuthenticated = true
        } catch {
            self.error = ErrorMapper.map(error)
        }

        isLoading = false
    }

    // MARK: - Logout

    public func logout() async {
        isLoading = true
        do {
            try await apiClient.logout()
        } catch {
            // Best-effort — clear local state regardless
        }
        try? keychain.deleteJWT()
        if let memberId = userProfile?.id {
            try? keychain.deleteEncryptedPrivateKey(memberId: memberId)
        }
        isAuthenticated = false
        userProfile = nil
        username = ""
        mnemonic = ""
        isLoading = false
    }

    // MARK: - Token Refresh

    public func refreshTokenIfNeeded() async {
        guard isAuthenticated else { return }
        do {
            let response = try await apiClient.refreshToken()
            try keychain.saveJWT(response.token)
            userProfile = response.user
        } catch {
            // Token refresh failed — session may be expired
            isAuthenticated = false
            self.error = ErrorMapper.map(error)
        }
    }

    // MARK: - Verify Existing Session

    public func verifySession() async {
        guard isAuthenticated else { return }
        do {
            userProfile = try await apiClient.verifyToken()
        } catch {
            isAuthenticated = false
            userProfile = nil
        }
    }
}
