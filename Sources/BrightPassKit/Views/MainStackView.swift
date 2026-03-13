import SwiftUI

/// Navigation destination values for the iOS NavigationStack.
@available(macOS 14.0, iOS 17.0, *)
enum AppDestination: Hashable {
    case vaultDetail(vaultId: String)
    case entryDetail(vaultId: String, entryId: String)
}

/// iOS three-level `NavigationStack` navigation:
/// vault list → vault detail → entry detail.
@available(macOS 14.0, iOS 17.0, *)
public struct MainStackView: View {
    @Bindable var router: NavigationRouter
    @Bindable var vaultListViewModel: VaultListViewModel
    @Bindable var vaultDetailViewModel: VaultDetailViewModel
    var entryDetailViewModel: EntryDetailViewModel
    let keychainStore: KeychainStoreProtocol
    let autoLockManager: AutoLockManager
    var recentEntriesTracker: RecentEntriesTracker

    @State private var showMasterPasswordPrompt = false
    @State private var pendingVaultId: String?
    @State private var sortViewModel = EntrySortViewModel()

    public init(router: NavigationRouter,
                vaultListViewModel: VaultListViewModel,
                vaultDetailViewModel: VaultDetailViewModel,
                entryDetailViewModel: EntryDetailViewModel,
                keychainStore: KeychainStoreProtocol,
                autoLockManager: AutoLockManager,
                recentEntriesTracker: RecentEntriesTracker) {
        self.router = router
        self.vaultListViewModel = vaultListViewModel
        self.vaultDetailViewModel = vaultDetailViewModel
        self.entryDetailViewModel = entryDetailViewModel
        self.keychainStore = keychainStore
        self.autoLockManager = autoLockManager
        self.recentEntriesTracker = recentEntriesTracker
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            VaultListView(viewModel: vaultListViewModel) { vault in
                pendingVaultId = vault.id
                router.navigateToVault(vault.id)
                showMasterPasswordPrompt = true
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .vaultDetail(let vaultId):
                    VaultDetailView(viewModel: vaultDetailViewModel, sortViewModel: sortViewModel, recentEntriesTracker: recentEntriesTracker) { entry in
                        router.navigateToEntry(entry.id)
                        router.path.append(AppDestination.entryDetail(vaultId: vaultId, entryId: entry.id))
                        Task {
                            await entryDetailViewModel.loadEntry(vaultId: vaultId, entryId: entry.id)
                        }
                    }
                    .navigationTitle(vaultDetailViewModel.vault?.name ?? "Vault")

                case .entryDetail(let vaultId, _):
                    EntryDetailView(viewModel: entryDetailViewModel, vaultId: vaultId) {
                        router.selectedEntryId = nil
                        router.path.removeLast()
                        Task { await vaultDetailViewModel.refreshEntries() }
                    }
                }
            }
        }
        .sheet(isPresented: $showMasterPasswordPrompt) {
            if let vaultId = pendingVaultId {
                MasterPasswordPromptView(
                    vaultId: vaultId,
                    viewModel: vaultDetailViewModel,
                    keychainStore: keychainStore
                )
            }
        }
        .onChange(of: vaultDetailViewModel.vault != nil) { _, unlocked in
            if unlocked, let vaultId = pendingVaultId {
                showMasterPasswordPrompt = false
                router.path.append(AppDestination.vaultDetail(vaultId: vaultId))
                pendingVaultId = nil
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
}
