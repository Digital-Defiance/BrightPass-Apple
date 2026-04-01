import SwiftUI

/// A row displaying vault name, entry count, and last-modified date.
@available(macOS 14.0, iOS 17.0, *)
struct VaultRowView: View {
    let vault: VaultMetadata
    let entryCount: Int?  // nil = locked, non-nil = client-derived count

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vault.name)
                .font(.headline)
            HStack {
                if let entryCount = entryCount {
                    Text("\(entryCount) entries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        Text("Locked")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(vault.lastModified, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entryCount != nil ? "\(vault.name), \(entryCount!) entries" : "\(vault.name), Locked")
    }
}

/// Vault list view with platform-adaptive navigation.
/// iOS: NavigationStack with pull-to-refresh.
/// macOS: Designed to be placed in a NavigationSplitView sidebar.
@available(macOS 14.0, iOS 17.0, *)
public struct VaultListView: View {
    @Bindable var viewModel: VaultListViewModel

    @State private var showCreateSheet = false
    @State private var newVaultName = ""
    @State private var newVaultPassword = ""
    @State private var vaultToDelete: VaultMetadata?

    let onSelectVault: (VaultMetadata) -> Void

    public init(viewModel: VaultListViewModel, onSelectVault: @escaping (VaultMetadata) -> Void) {
        self.viewModel = viewModel
        self.onSelectVault = onSelectVault
    }

    public var body: some View {
        List {
            ForEach(viewModel.vaults) { vault in
                Button {
                    onSelectVault(vault)
                } label: {
                    VaultRowView(vault: vault, entryCount: viewModel.decryptedEntryCounts[vault.id])
                }
                #if os(iOS)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        vaultToDelete = vault
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #else
                .contextMenu {
                    Button(role: .destructive) {
                        vaultToDelete = vault
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #endif
            }
        }
        #if os(iOS)
        .refreshable {
            await viewModel.loadVaults()
        }
        #endif
        .overlay {
            if viewModel.isLoading && viewModel.vaults.isEmpty {
                ProgressView("Loading vaults…")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newVaultName = ""
                    newVaultPassword = ""
                    showCreateSheet = true
                } label: {
                    Label("Create Vault", systemImage: "plus")
                }
                .accessibilityLabel("Create a new vault")
            }
        }
        .navigationTitle("Vaults")
        .alert("Delete Vault?",
               isPresented: Binding(
                   get: { vaultToDelete != nil },
                   set: { if !$0 { vaultToDelete = nil } }
               ),
               presenting: vaultToDelete
        ) { vault in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteVault(vault) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { vault in
            Text("Are you sure you want to delete \"\(vault.name)\"? This action cannot be undone.")
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateVaultSheet(
                name: $newVaultName,
                password: $newVaultPassword,
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.createVault(name: newVaultName, masterPassword: newVaultPassword)
                    if viewModel.error == nil {
                        showCreateSheet = false
                    }
                }
            }
        }
        .task {
            if viewModel.vaults.isEmpty {
                await viewModel.loadVaults()
            }
        }
    }
}

// MARK: - Create Vault Sheet

@available(macOS 14.0, iOS 17.0, *)
struct CreateVaultSheet: View {
    @Binding var name: String
    @Binding var password: String
    let isLoading: Bool
    let onCreate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Vault Name", text: $name)
                        .accessibilityLabel("Vault name")
                    SecureField("Master Password", text: $password)
                        .accessibilityLabel("Master password")
                }
            }
            .navigationTitle("New Vault")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { onCreate() }
                        .disabled(name.isEmpty || password.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
}
