import SwiftUI

/// Sheet view that prompts for the master password to unlock a vault.
/// Offers biometric authentication when enabled for the vault.
/// Dismisses automatically when the vault is successfully unlocked.
@available(macOS 14.0, iOS 17.0, *)
public struct MasterPasswordPromptView: View {
    let vaultId: String
    @Bindable var viewModel: VaultDetailViewModel
    let keychainStore: KeychainStoreProtocol

    @State private var masterPassword = ""
    @State private var biometricAvailable = false
    @Environment(\.dismiss) private var dismiss

    public init(vaultId: String, viewModel: VaultDetailViewModel, keychainStore: KeychainStoreProtocol) {
        self.vaultId = vaultId
        self.viewModel = viewModel
        self.keychainStore = keychainStore
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Master Password", text: $masterPassword)
                        .accessibilityLabel("Master password")
                        .onSubmit { unlock() }
                }

                if biometricAvailable {
                    Section {
                        Button {
                            unlockWithBiometric()
                        } label: {
                            Label("Unlock with Face ID / Touch ID", systemImage: "faceid")
                        }
                        .accessibilityLabel("Unlock with biometrics")
                    }
                }

                if let error = viewModel.error {
                    Section {
                        Text(error.userMessage)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(error.userMessage)")
                    }
                }
            }
            .navigationTitle("Unlock Vault")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock") { unlock() }
                        .disabled(masterPassword.isEmpty || viewModel.isLoading)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .onChange(of: viewModel.vault != nil) { _, unlocked in
                if unlocked { dismiss() }
            }
            .task {
                biometricAvailable = (try? keychainStore.hasBiometricProtectedHash(vaultId: vaultId)) ?? false
            }
        }
    }

    private func unlock() {
        guard !masterPassword.isEmpty else { return }
        Task {
            await viewModel.openVault(id: vaultId, masterPassword: masterPassword)
        }
    }

    private func unlockWithBiometric() {
        Task {
            await viewModel.openVaultBiometric(id: vaultId)
        }
    }
}
