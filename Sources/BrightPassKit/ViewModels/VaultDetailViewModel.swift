import Foundation

/// Manages the state for a single vault's detail view, including vault unlock,
/// entry listing, search, filtering, and lock operations.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class VaultDetailViewModel {

    public var vault: DecryptedVault?
    public var entries: [EntryPropertyRecord] = []
    public var searchQuery: String = ""
    public var typeFilter: EntryType?
    public var favoritesOnly: Bool = false
    public var isLoading: Bool = false
    public var error: AppError?
    /// Set to `true` when biometric evaluation fails and the UI should present the manual password prompt.
    public var showMasterPasswordFallback: Bool = false

    private let apiClient: APIClientProtocol
    private let keychainStore: KeychainStoreProtocol
    private let biometricAuthenticator: BiometricAuthenticatorProtocol?

    public init(apiClient: APIClientProtocol,
                keychainStore: KeychainStoreProtocol,
                biometricAuthenticator: BiometricAuthenticatorProtocol? = nil) {
        self.apiClient = apiClient
        self.keychainStore = keychainStore
        self.biometricAuthenticator = biometricAuthenticator
    }

    // MARK: - Vault Unlock

    /// Opens a vault using the master password.
    public func openVault(id: String, masterPassword: String) async {
        isLoading = true
        error = nil
        do {
            let decrypted = try await apiClient.openVault(id: id, masterPassword: masterPassword)
            vault = decrypted
            entries = try await apiClient.listEntries(vaultId: id)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Opens a vault using biometric authentication.
    /// Checks if biometric is enabled for the vault, evaluates biometric policy via LAContext,
    /// retrieves the stored master password hash, and opens the vault.
    /// On biometric failure, sets `showMasterPasswordFallback` so the UI can present the manual prompt.
    public func openVaultBiometric(id: String) async {
        isLoading = true
        error = nil
        showMasterPasswordFallback = false

        // 1. Check if biometric is enabled for this vault
        guard let hasBiometric = try? keychainStore.hasBiometricProtectedHash(vaultId: id),
              hasBiometric else {
            // No biometric configured — fall back to password prompt
            showMasterPasswordFallback = true
            isLoading = false
            return
        }

        // 2. Evaluate biometric policy
        guard let authenticator = biometricAuthenticator,
              authenticator.canEvaluateBiometrics() else {
            showMasterPasswordFallback = true
            isLoading = false
            return
        }

        let success = await authenticator.evaluateBiometrics(reason: "Unlock your vault")
        guard success else {
            // Biometric failed or cancelled — fall back to password prompt
            showMasterPasswordFallback = true
            isLoading = false
            return
        }

        // 3. Retrieve stored hash and open vault
        do {
            guard let hash = try keychainStore.loadMasterPasswordHash(vaultId: id) else {
                self.error = .validationError(messages: ["No biometric credential found for this vault."])
                showMasterPasswordFallback = true
                isLoading = false
                return
            }
            let decrypted = try await apiClient.openVault(id: id, masterPassword: hash)
            vault = decrypted
            entries = try await apiClient.listEntries(vaultId: id)
        } catch {
            self.error = ErrorMapper.map(error)
            showMasterPasswordFallback = true
        }
        isLoading = false
    }

    // MARK: - Biometric Settings

    /// Returns whether biometric unlock is enabled for the given vault.
    public func isBiometricEnabled(vaultId: String) -> Bool {
        (try? keychainStore.hasBiometricProtectedHash(vaultId: vaultId)) ?? false
    }

    /// Enables biometric unlock for a vault by storing the master password hash
    /// with biometric protection in the Keychain.
    public func enableBiometric(vaultId: String, masterPasswordHash: String) throws {
        try keychainStore.saveMasterPasswordHash(masterPasswordHash, vaultId: vaultId, biometricProtected: true)
    }

    /// Disables biometric unlock for a vault by removing the stored hash from the Keychain.
    public func disableBiometric(vaultId: String) throws {
        try keychainStore.deleteMasterPasswordHash(vaultId: vaultId)
    }

    // MARK: - Search

    /// Sends the current search query to the API and updates the entries list.
    public func searchEntries() async {
        guard let vaultId = vault?.id else { return }
        isLoading = true
        error = nil
        do {
            entries = try await apiClient.searchEntries(vaultId: vaultId, query: searchQuery)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    // MARK: - Filtering

    /// Applies local type and favorite filters with AND logic.
    /// Returns the filtered subset of `entries`.
    public func filterEntries() -> [EntryPropertyRecord] {
        var result = entries
        if let typeFilter {
            result = result.filter { $0.type == typeFilter }
        }
        if favoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        return result
    }

    // MARK: - Lock

    /// Clears all decrypted data and resets state.
    public func lockVault() {
        vault = nil
        entries = []
        searchQuery = ""
        typeFilter = nil
        favoritesOnly = false
        error = nil
        showMasterPasswordFallback = false
    }

    // MARK: - Entry Operations

    /// Creates a new entry in the current vault and refreshes the entry list.
    public func createEntry(_ entry: VaultEntry) async {
        guard let vaultId = vault?.id else { return }
        isLoading = true
        error = nil
        do {
            _ = try await apiClient.createEntry(vaultId: vaultId, entry: entry)
            entries = try await apiClient.listEntries(vaultId: vaultId)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Deletes an entry from the current vault and removes it from the local list.
    public func deleteEntry(_ entry: EntryPropertyRecord) async {
        guard let vaultId = vault?.id else { return }
        isLoading = true
        error = nil
        do {
            try await apiClient.deleteEntry(vaultId: vaultId, entryId: entry.id)
            entries.removeAll { $0.id == entry.id }
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Refreshes the entry list from the API.
    public func refreshEntries() async {
        guard let vaultId = vault?.id else { return }
        isLoading = true
        error = nil
        do {
            entries = try await apiClient.listEntries(vaultId: vaultId)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }
}
