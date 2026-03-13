import Foundation

/// Manages vault rename operations with optimistic UI updates.
/// On success, modifies the vault name in both `VaultListViewModel` and `VaultDetailViewModel`
/// without requiring a full refresh.
///
/// **Validates: Requirements 23.1, 23.2, 23.3, 23.4**
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class VaultRenameViewModel {

    public var newName: String = ""
    public var isLoading: Bool = false
    public var error: AppError?

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Renames a vault via the API and performs optimistic UI updates on the provided view models.
    /// - Parameters:
    ///   - vaultId: The vault to rename.
    ///   - vaultListViewModel: Optional list VM to update the vault name in the list.
    ///   - vaultDetailViewModel: Optional detail VM to update the current vault's name.
    public func renameVault(
        vaultId: String,
        vaultListViewModel: VaultListViewModel? = nil,
        vaultDetailViewModel: VaultDetailViewModel? = nil
    ) async {
        error = nil
        isLoading = true
        do {
            let updated = try await apiClient.renameVault(id: vaultId, name: newName)

            // Optimistic update: replace the matching vault in the list
            if let listVM = vaultListViewModel,
               let index = listVM.vaults.firstIndex(where: { $0.id == vaultId }) {
                listVM.vaults[index] = updated
            }

            // Optimistic update: replace the current vault in the detail view
            if let detailVM = vaultDetailViewModel, detailVM.vault?.id == vaultId {
                detailVM.vault = DecryptedVault(
                    id: vaultId,
                    name: updated.name,
                    entries: detailVM.vault?.entries ?? []
                )
            }
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }
}
