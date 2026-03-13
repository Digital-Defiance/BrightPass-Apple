import Foundation

/// Manages vault sharing: loading shared members, sharing with new members, and revoking access.
///
/// **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5**
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class ShareVaultViewModel {

    public var sharedMembers: [SharedMember] = []
    public var isLoading: Bool = false
    public var error: AppError?

    @ObservationIgnored private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Fetches the list of members with whom the vault is currently shared.
    public func loadSharedMembers(vaultId: String) async {
        isLoading = true
        error = nil
        do {
            sharedMembers = try await apiClient.listSharedMembers(vaultId: vaultId)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Shares the vault with a member at the specified permission level.
    public func shareVault(vaultId: String, memberId: String, permission: SharePermission) async {
        isLoading = true
        error = nil
        do {
            try await apiClient.shareVault(vaultId: vaultId, memberId: memberId, permission: permission)
            // Reload the member list to reflect the new share
            sharedMembers = try await apiClient.listSharedMembers(vaultId: vaultId)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Revokes a member's access and removes them from the local list on success.
    public func revokeAccess(vaultId: String, memberId: String) async {
        isLoading = true
        error = nil
        do {
            try await apiClient.revokeShare(vaultId: vaultId, memberId: memberId)
            sharedMembers.removeAll { $0.memberId == memberId }
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }
}
