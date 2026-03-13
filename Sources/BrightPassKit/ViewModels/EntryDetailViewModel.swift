import Foundation

/// Manages the state for a single entry's detail view, including loading,
/// saving (create/update), deleting, and password visibility toggling.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class EntryDetailViewModel {

    public var entry: VaultEntry?
    public var isEditing: Bool = false
    public var isPasswordVisible: Bool = false
    public var isLoading: Bool = false
    public var error: AppError?

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Load

    /// Fetches the full entry details from the API.
    public func loadEntry(vaultId: String, entryId: String) async {
        isLoading = true
        error = nil
        do {
            entry = try await apiClient.getEntry(vaultId: vaultId, entryId: entryId)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    // MARK: - Save

    /// Creates or updates the entry via the API.
    /// If the current entry has an id, it performs an update; otherwise it creates a new entry.
    public func saveEntry(vaultId: String) async {
        guard let current = entry else { return }
        isLoading = true
        error = nil
        do {
            let saved = try await apiClient.updateEntry(vaultId: vaultId, entryId: current.id, entry: current)
            entry = saved
            isEditing = false
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    // MARK: - Delete

    /// Deletes the current entry from the vault.
    public func deleteEntry(vaultId: String) async {
        guard let current = entry else { return }
        isLoading = true
        error = nil
        do {
            try await apiClient.deleteEntry(vaultId: vaultId, entryId: current.id)
            entry = nil
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    // MARK: - Password Visibility

    /// Toggles password field visibility.
    public func togglePasswordVisibility() {
        isPasswordVisible.toggle()
    }
}
