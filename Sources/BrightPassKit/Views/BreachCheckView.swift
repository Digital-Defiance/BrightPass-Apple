import SwiftUI

/// Displays breach check results: a warning with breach count or a safe confirmation.
/// Shows a loading indicator while the request is in progress.
///
/// **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**
@available(macOS 14.0, iOS 17.0, *)
public struct BreachCheckView: View {

    @Bindable var viewModel: BreachCheckViewModel

    /// The password to check for breaches.
    private let password: String

    /// Called when the user dismisses the view.
    private let onDismiss: (() -> Void)?

    public init(viewModel: BreachCheckViewModel, password: String, onDismiss: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.password = password
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView("Checking password…")
                    .accessibilityLabel("Checking password against breach database")
            } else if let result = viewModel.result {
                resultView(result)
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                // Initial state before check runs
                ProgressView("Checking password…")
                    .accessibilityLabel("Checking password against breach database")
            }
        }
        .padding()
        .task {
            await viewModel.checkPassword(password)
        }
    }

    // MARK: - Result Display

    @ViewBuilder
    private func resultView(_ result: BreachCheckResult) -> some View {
        if result.breached {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text("Password Compromised")
                .font(.headline)
                .foregroundStyle(.red)

            if let count = result.breachCount {
                Text("This password has appeared in \(count) known data \(count == 1 ? "breach" : "breaches"). You should change it immediately.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("This password has been found in known data breaches. You should change it immediately.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("Password Not Found in Breaches")
                .font(.headline)
                .foregroundStyle(.green)

            Text("This password is not known to be compromised.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Error Display

    @ViewBuilder
    private func errorView(_ error: AppError) -> some View {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 40))
            .foregroundStyle(.orange)
            .accessibilityHidden(true)

        Text("Breach Check Failed")
            .font(.headline)

        Text(error.userMessage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

        if error.isRetryable {
            Button("Retry") {
                Task {
                    await viewModel.checkPassword(password)
                }
            }
            .accessibilityLabel("Retry breach check")
        }
    }
}
