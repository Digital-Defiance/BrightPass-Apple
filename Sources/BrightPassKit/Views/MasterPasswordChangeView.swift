import SwiftUI

/// Form for changing a vault's master password.
/// Shows current password, new password, and confirmation fields.
/// Displays success confirmation or error messages.
///
/// **Validates: Requirements 22.1, 22.2, 22.5**
@available(macOS 14.0, iOS 17.0, *)
public struct MasterPasswordChangeView: View {

    @Bindable var viewModel: MasterPasswordChangeViewModel

    private let vaultId: String
    private let onDismiss: (() -> Void)?

    public init(viewModel: MasterPasswordChangeViewModel, vaultId: String, onDismiss: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.vaultId = vaultId
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Form {
            if viewModel.isSuccess {
                successSection
            } else {
                passwordFieldsSection
                changeButtonSection
            }
        }
        .navigationTitle("Change Master Password")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .accessibilityLabel("Changing master password")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.userMessage)
            }
        }
    }

    // MARK: - Sections

    private var passwordFieldsSection: some View {
        Section {
            SecureField("Current Password", text: $viewModel.currentPassword)
                .accessibilityLabel("Current master password")
            SecureField("New Password", text: $viewModel.newPassword)
                .accessibilityLabel("New master password")
            SecureField("Confirm New Password", text: $viewModel.confirmNewPassword)
                .accessibilityLabel("Confirm new master password")
        }
    }

    private var changeButtonSection: some View {
        Section {
            Button("Change Password") {
                Task {
                    await viewModel.changePassword(vaultId: vaultId)
                }
            }
            .disabled(
                viewModel.currentPassword.isEmpty ||
                viewModel.newPassword.isEmpty ||
                viewModel.confirmNewPassword.isEmpty ||
                viewModel.isLoading
            )
            .accessibilityLabel("Submit password change")
        }
    }

    private var successSection: some View {
        Section {
            Label("Master password changed successfully.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Password changed successfully")

            if let dismiss = onDismiss {
                Button("Done") { dismiss() }
                    .accessibilityLabel("Dismiss password change")
            }
        }
    }
}
