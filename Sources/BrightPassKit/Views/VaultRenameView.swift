import SwiftUI

/// Rename dialog pre-populated with the current vault name.
/// Accessible from vault detail view and context menu on vault list items.
///
/// **Validates: Requirements 23.1, 23.2**
@available(macOS 14.0, iOS 17.0, *)
public struct VaultRenameView: View {

    @Bindable var viewModel: VaultRenameViewModel

    private let vaultId: String
    private let currentName: String
    private let vaultListViewModel: VaultListViewModel?
    private let vaultDetailViewModel: VaultDetailViewModel?
    private let onDismiss: (() -> Void)?

    public init(
        viewModel: VaultRenameViewModel,
        vaultId: String,
        currentName: String,
        vaultListViewModel: VaultListViewModel? = nil,
        vaultDetailViewModel: VaultDetailViewModel? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.vaultId = vaultId
        self.currentName = currentName
        self.vaultListViewModel = vaultListViewModel
        self.vaultDetailViewModel = vaultDetailViewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Form {
            Section {
                TextField("Vault Name", text: $viewModel.newName)
                    .accessibilityLabel("New vault name")
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
            }

            Section {
                Button("Rename") {
                    Task {
                        await viewModel.renameVault(
                            vaultId: vaultId,
                            vaultListViewModel: vaultListViewModel,
                            vaultDetailViewModel: vaultDetailViewModel
                        )
                        if viewModel.error == nil {
                            onDismiss?()
                        }
                    }
                }
                .disabled(viewModel.newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                .accessibilityLabel("Confirm rename")
            }
        }
        .navigationTitle("Rename Vault")
        .onAppear {
            viewModel.newName = currentName
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .accessibilityLabel("Renaming vault")
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
}
