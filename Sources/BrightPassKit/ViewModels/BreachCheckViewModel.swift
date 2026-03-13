import Foundation

/// Manages breach check requests against the API and exposes the result.
///
/// **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class BreachCheckViewModel {

    public var result: BreachCheckResult?
    public var isLoading: Bool = false
    public var error: AppError?

    @ObservationIgnored private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Checks whether the given password has appeared in known data breaches.
    public func checkPassword(_ password: String) async {
        isLoading = true
        error = nil
        result = nil
        do {
            result = try await apiClient.checkBreach(password: password)
            isLoading = false
        } catch {
            self.error = ErrorMapper.map(error)
            isLoading = false
        }
    }
}
