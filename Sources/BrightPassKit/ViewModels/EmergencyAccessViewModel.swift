import Foundation

/// Manages emergency access configuration and Shamir-based vault recovery.
///
/// `recover()` validates that the provided share count meets the threshold
/// before making an API call. If insufficient, it sets a validation error locally.
///
/// **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7**
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class EmergencyAccessViewModel {

    public var config: EmergencyAccessConfig?
    public var recoveredVault: DecryptedVault?
    public var isLoading: Bool = false
    public var error: AppError?

    @ObservationIgnored private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Fetches the current emergency access configuration for a vault.
    public func loadConfig(vaultId: String) async {
        isLoading = true
        error = nil
        do {
            config = try await apiClient.getEmergencyAccessConfig(vaultId: vaultId)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Configures emergency access with the specified share count and threshold.
    public func configure(vaultId: String, totalShares: Int, threshold: Int) async {
        isLoading = true
        error = nil
        do {
            let newConfig = EmergencyAccessConfig(totalShares: totalShares, threshold: threshold, trustees: [])
            try await apiClient.configureEmergencyAccess(vaultId: vaultId, config: newConfig)
            config = try await apiClient.getEmergencyAccessConfig(vaultId: vaultId)
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }

    /// Attempts vault recovery using the provided shares.
    ///
    /// If the share count is less than the configured threshold, sets a validation
    /// error without making an API call.
    @discardableResult
    public func recover(vaultId: String, shares: [String]) async -> DecryptedVault? {
        isLoading = true
        error = nil
        recoveredVault = nil

        if let cfg = config, shares.count < cfg.threshold {
            error = .validationError(messages: [
                "Insufficient shares: \(shares.count) provided, \(cfg.threshold) required."
            ])
            isLoading = false
            return nil
        }

        do {
            let vault = try await apiClient.recoverVault(vaultId: vaultId, shares: shares)
            recoveredVault = vault
            isLoading = false
            return vault
        } catch {
            self.error = ErrorMapper.map(error)
            isLoading = false
            return nil
        }
    }
}
