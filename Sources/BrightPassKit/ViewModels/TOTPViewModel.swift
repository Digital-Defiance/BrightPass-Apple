import Foundation

/// Manages TOTP code generation, countdown, and auto-refresh.
///
/// Requests a code from the API, displays it with a countdown timer,
/// and automatically refreshes when the code expires.
///
/// **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5**
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class TOTPViewModel {

    public var currentCode: String?
    public var remainingSeconds: Int = 30
    public var isLoading: Bool = false
    public var error: AppError?

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Requests a TOTP code from the API and starts the countdown/auto-refresh loop.
    public func startCodeGeneration(secret: String) async {
        stopCodeGeneration()
        await fetchAndStartCountdown(secret: secret)
    }

    /// Cancels the refresh task and stops the countdown.
    public func stopCodeGeneration() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Copies the current code to the clipboard.
    /// Platform-specific clipboard access is handled by the View layer,
    /// since BrightPassKit has no UIKit/AppKit dependencies.
    public func copyCode() -> String? {
        return currentCode
    }

    // MARK: - Private

    private func fetchAndStartCountdown(secret: String) async {
        isLoading = true
        error = nil
        do {
            let result = try await apiClient.generateTOTP(secret: secret)
            currentCode = result.code
            remainingSeconds = result.remainingSeconds
            isLoading = false
            startCountdown(secret: secret, seconds: result.remainingSeconds)
        } catch {
            self.error = ErrorMapper.map(error)
            isLoading = false
        }
    }

    private func startCountdown(secret: String, seconds: Int) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            var remaining = seconds
            while !Task.isCancelled && remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                remaining -= 1
                self?.remainingSeconds = remaining
            }
            guard !Task.isCancelled else { return }
            // Auto-refresh on expiry
            await self?.fetchAndStartCountdown(secret: secret)
        }
    }
}
