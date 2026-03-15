import SwiftUI

/// macOS three-column navigation using `NavigationSplitView`.
/// Sidebar: vault list, Content: entry list, Detail: entry detail.
@available(macOS 14.0, iOS 17.0, *)
public struct MainSplitView: View {
    @Bindable var router: NavigationRouter
    @Bindable var vaultListViewModel: VaultListViewModel
    @Bindable var vaultDetailViewModel: VaultDetailViewModel
    var entryDetailViewModel: EntryDetailViewModel
    let keychainStore: KeychainStoreProtocol
    let autoLockManager: AutoLockManager
    @Bindable var favoritesViewModel: FavoritesViewModel
    var recentEntriesTracker: RecentEntriesTracker

    @State private var showMasterPasswordPrompt = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sortViewModel = EntrySortViewModel()
    @State private var showFavorites = false
    @State private var showCreateSheet = false
    @State private var newVaultName = ""
    @State private var newVaultPassword = ""

    public init(router: NavigationRouter,
                vaultListViewModel: VaultListViewModel,
                vaultDetailViewModel: VaultDetailViewModel,
                entryDetailViewModel: EntryDetailViewModel,
                keychainStore: KeychainStoreProtocol,
                autoLockManager: AutoLockManager,
                favoritesViewModel: FavoritesViewModel,
                recentEntriesTracker: RecentEntriesTracker) {
        self.router = router
        self.vaultListViewModel = vaultListViewModel
        self.vaultDetailViewModel = vaultDetailViewModel
        self.entryDetailViewModel = entryDetailViewModel
        self.keychainStore = keychainStore
        self.autoLockManager = autoLockManager
        self.favoritesViewModel = favoritesViewModel
        self.recentEntriesTracker = recentEntriesTracker
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Vault list + Favorites
            List {
                Section("Vaults") {
                    ForEach(vaultListViewModel.vaults) { vault in
                        Button {
                            showFavorites = false
                            router.navigateToVault(vault.id)
                            showMasterPasswordPrompt = true
                        } label: {
                            VaultRowView(vault: vault)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Favorites") {
                    Button {
                        showFavorites = true
                        router.selectedVaultId = nil
                        router.selectedEntryId = nil
                    } label: {
                        Label("All Favorites", systemImage: "star.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show all favorites")
                }
            }
            .navigationTitle("BrightPass")
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
            .task {
                if vaultListViewModel.vaults.isEmpty {
                    await vaultListViewModel.loadVaults()
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateVaultSheet(
                    name: $newVaultName,
                    password: $newVaultPassword,
                    isLoading: vaultListViewModel.isLoading
                ) {
                    Task {
                        await vaultListViewModel.createVault(name: newVaultName, masterPassword: newVaultPassword)
                        if vaultListViewModel.error == nil {
                            showCreateSheet = false
                        }
                    }
                }
            }
        } content: {
            // Content: Entry list or Favorites
            if showFavorites {
                FavoritesView(viewModel: favoritesViewModel) { favorite in
                    showFavorites = false
                    router.navigateToVault(favorite.vaultId)
                    router.navigateToEntry(favorite.entry.id)
                    Task {
                        await entryDetailViewModel.loadEntry(
                            vaultId: favorite.vaultId,
                            entryId: favorite.entry.id
                        )
                    }
                }
            } else if router.selectedVaultId != nil, vaultDetailViewModel.vault != nil {
                VaultDetailView(viewModel: vaultDetailViewModel, sortViewModel: sortViewModel, recentEntriesTracker: recentEntriesTracker) { entry in
                    router.navigateToEntry(entry.id)
                    Task {
                        await entryDetailViewModel.loadEntry(
                            vaultId: vaultDetailViewModel.vault?.id ?? "",
                            entryId: entry.id
                        )
                    }
                }
            } else if router.selectedVaultId != nil {
                ContentUnavailableView("Vault Locked",
                                       systemImage: "lock.fill",
                                       description: Text("Enter your master password to unlock this vault."))
            } else {
                ContentUnavailableView("Select a Vault",
                                       systemImage: "lock.rectangle.stack",
                                       description: Text("Choose a vault from the sidebar."))
            }
        } detail: {
            // Detail: Entry detail
            if router.selectedEntryId != nil, let vaultId = vaultDetailViewModel.vault?.id {
                EntryDetailView(viewModel: entryDetailViewModel, vaultId: vaultId) {
                    router.selectedEntryId = nil
                    Task { await vaultDetailViewModel.refreshEntries() }
                }
            } else if router.selectedVaultId != nil, vaultDetailViewModel.vault != nil {
                ContentUnavailableView("Select an Entry",
                                       systemImage: "doc.text.magnifyingglass",
                                       description: Text("Choose an entry from the list."))
            } else {
                ContentUnavailableView("No Selection",
                                       systemImage: "sidebar.left",
                                       description: Text("Select a vault and entry to view details."))
            }
        }
        .navigationTitle(navigationTitle)
        .sheet(isPresented: $showMasterPasswordPrompt) {
            if let vaultId = router.selectedVaultId {
                MasterPasswordPromptView(
                    vaultId: vaultId,
                    viewModel: vaultDetailViewModel,
                    keychainStore: keychainStore
                )
            }
        }
        .onChange(of: vaultDetailViewModel.vault != nil) { _, unlocked in
            if unlocked {
                showMasterPasswordPrompt = false
            }
        }
        .onChange(of: autoLockManager.isLocked) { _, locked in
            if locked {
                vaultDetailViewModel.lockVault()
                router.returnToVaultList()
                autoLockManager.isLocked = false
            }
        }
    }

    private var navigationTitle: String {
        if let entryTitle = entryDetailViewModel.entry?.title, router.selectedEntryId != nil {
            return entryTitle
        }
        if let vaultName = vaultDetailViewModel.vault?.name, router.selectedVaultId != nil {
            return vaultName
        }
        return "BrightPass"
    }
}
