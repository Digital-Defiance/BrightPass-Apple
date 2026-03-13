import Foundation

/// Manages the audit log for a vault, fetching and sorting entries by timestamp descending.
///
/// **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class AuditLogViewModel {

    public var entries: [AuditLogEntry] = []
    public var isLoading: Bool = false
    public var error: AppError?

    @ObservationIgnored private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Fetches audit log entries from the API and sorts them by timestamp descending (newest first).
    public func loadAuditLog(vaultId: String) async {
        isLoading = true
        error = nil
        do {
            let fetched = try await apiClient.getAuditLog(vaultId: vaultId)
            entries = fetched.sorted { $0.timestamp > $1.timestamp }
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }
}
