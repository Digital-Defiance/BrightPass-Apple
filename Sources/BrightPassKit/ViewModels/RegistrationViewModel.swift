import Foundation

/// Manages registration state: account creation, mnemonic generation, and key storage.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class RegistrationViewModel {

    // MARK: - Public State

    public var username: String = ""
    public var email: String = ""
    public var password: String = ""
    public var confirmPassword: String = ""
    public var passwordStrength: PasswordStrengthLevel = .weak
    public var isLoading: Bool = false
    public var error: AppError?
    public var fieldErrors: [String: String] = [:]
    public var generatedMnemonic: String?
    public var hasSavedMnemonic: Bool = false
    public var isRegistered: Bool = false

    // MARK: - Pending State (between register and confirmMnemonicSaved)

    private var pendingJWT: String?
    private var pendingMemberId: String?
    private var pendingMemberResult: MemberResult?

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol
    private let keychain: KeychainStoreProtocol
    private let sdkWrapper: SDKWrapperProtocol
    private let keyring: KeyringProtocol

    public init(apiClient: APIClientProtocol,
                keychain: KeychainStoreProtocol,
                sdkWrapper: SDKWrapperProtocol = FallbackSDKWrapper(),
                keyring: KeyringProtocol = SimpleKeyring()) {
        self.apiClient = apiClient
        self.keychain = keychain
        self.sdkWrapper = sdkWrapper
        self.keyring = keyring
    }

    // MARK: - Register

    /// Validates input, registers via API, generates mnemonic, and derives keys.
    /// Does NOT store JWT/keys yet — waits for `confirmMnemonicSaved()`.
    public func register() async {
        // Validate fields
        var errors: [String: String] = [:]
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors["username"] = "Username is required"
        }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors["email"] = "Email is required"
        }
        if password != confirmPassword {
            errors["confirmPassword"] = "Passwords do not match"
        }
        if !errors.isEmpty {
            fieldErrors = errors
            return
        }

        isLoading = true
        error = nil
        fieldErrors = [:]

        do {
            let response = try await apiClient.register(
                username: username,
                email: email,
                password: password
            )

            // Generate mnemonic and derive keys
            guard let mnemonic = sdkWrapper.generateMnemonic() else {
                error = .validationError(messages: ["Failed to generate mnemonic."])
                isLoading = false
                return
            }

            guard let member = sdkWrapper.loginWithMnemonic(mnemonic, name: username, email: email) else {
                error = .validationError(messages: ["Failed to derive keys from mnemonic."])
                isLoading = false
                return
            }

            // Store pending state — don't persist to keychain until mnemonic is confirmed
            pendingJWT = response.data.token
            pendingMemberId = response.data.memberId
            pendingMemberResult = member
            generatedMnemonic = mnemonic
        } catch {
            let mapped = ErrorMapper.map(error)
            self.error = mapped

            // Try to parse field-specific errors from validation errors
            if case .validationError(let messages) = mapped {
                for message in messages {
                    let lower = message.lowercased()
                    if lower.contains("username") {
                        fieldErrors["username"] = message
                    } else if lower.contains("email") {
                        fieldErrors["email"] = message
                    } else if lower.contains("password") {
                        fieldErrors["password"] = message
                    }
                }
            }
        }

        isLoading = false
    }

    // MARK: - Confirm Mnemonic Saved

    /// Completes registration by storing JWT and encrypted private key in the keychain.
    public func confirmMnemonicSaved() {
        guard let jwt = pendingJWT,
              let member = pendingMemberResult else { return }

        do {
            try keychain.saveJWT(jwt)
            let encryptedKey = try keyring.encrypt(data: member.privateKey)
            try keychain.saveEncryptedPrivateKey(encryptedKey, memberId: member.id)

            hasSavedMnemonic = true
            isRegistered = true

            // Clear pending state
            pendingJWT = nil
            pendingMemberId = nil
            pendingMemberResult = nil
        } catch {
            self.error = .validationError(messages: ["Failed to store credentials: \(error.localizedDescription)"])
        }
    }

    // MARK: - Password Strength

    /// Evaluates password strength using the shared `PasswordStrengthEvaluator`.
    /// Call this whenever the password field changes.
    public func evaluatePasswordStrength() {
        passwordStrength = PasswordStrengthEvaluator.evaluate(password)
    }
}
