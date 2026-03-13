import Foundation

/// Manages importing entries from other password managers via the API.
///
/// **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class ImportViewModel {

    public var selectedSource: ImportSource?
    public var result: ImportResult?
    public var isLoading: Bool = false
    public var error: AppError?

    /// Called after a successful import so the caller can refresh the entry list.
    public var onImportSuccess: (() -> Void)?

    @ObservationIgnored private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Sends the file data to the API import endpoint for the selected source.
    public func importFile(vaultId: String, source: ImportSource, fileData: Data) async {
        isLoading = true
        error = nil
        result = nil
        do {
            result = try await apiClient.importEntries(vaultId: vaultId, source: source, fileData: fileData)
            onImportSuccess?()
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }
}
