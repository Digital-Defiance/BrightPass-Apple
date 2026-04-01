import Foundation

/// Manages the list of vaults, supporting load, create, and delete operations.
/// UI state mutations are confined to the main actor.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class VaultListViewModel {

    public var vaults: [VaultMetadata] = []
    public var isLoading: Bool = false
    public var error: AppError?
    public var decryptedEntryCounts: [String: Int] = [:]

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Fetches all vaults from the API and replaces the current list.
    public func loadVaults() async {
        isLoading = true
        error = nil
        do {
            vaults = try await apiClient.listVaults()
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Creates a new vault and appends it to the list on success (no full refresh).
    public func createVault(name: String, masterPassword: String) async {
        isLoading = true
        error = nil
        do {
            let newVault = try await apiClient.createVault(name: name, masterPassword: masterPassword)
            vaults.append(newVault)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Deletes a vault by ID and removes it from the list on success (no full refresh).
    public func deleteVault(_ vault: VaultMetadata) async {
        isLoading = true
        error = nil
        do {
            try await apiClient.deleteVault(id: vault.id)
            vaults.removeAll { $0.id == vault.id }
            decryptedEntryCounts.removeValue(forKey: vault.id)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Sets the client-side derived entry count for a decrypted vault.
    public func setEntryCount(for vaultId: String, count: Int) {
        decryptedEntryCounts[vaultId] = count
    }

    /// Clears the entry count for a vault (e.g. when it is locked).
    public func clearEntryCount(for vaultId: String) {
        decryptedEntryCounts.removeValue(forKey: vaultId)
    }
}
