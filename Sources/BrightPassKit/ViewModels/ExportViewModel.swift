import Foundation

/// Manages vault entry export state.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class ExportViewModel {

    public var selectedFormat: ExportFormat = .csv
    public var exportedData: Data?
    public var isLoading: Bool = false
    public var error: AppError?

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Sends an export request and stores the returned data.
    public func exportEntries(vaultId: String) async {
        isLoading = true
        error = nil
        exportedData = nil
        do {
            exportedData = try await apiClient.exportEntries(vaultId: vaultId, format: selectedFormat)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }
}
