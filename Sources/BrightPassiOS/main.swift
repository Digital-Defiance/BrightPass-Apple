// BrightPassiOS — iOS app target

import SwiftUI
import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
struct BrightPassApp: App {
    @State private var config = ConfigurationManager(environment: .development)
    @State private var keychain = KeychainStore()
    @State private var router = NavigationRouter()
    @State private var autoLockManager = AutoLockManager()
    @State private var authViewModel: AuthViewModel?
    @State private var vaultListViewModel: VaultListViewModel?
    @State private var vaultDetailViewModel: VaultDetailViewModel?
    @State private var entryDetailViewModel: EntryDetailViewModel?
    @State private var onboardingViewModel = OnboardingViewModel()
    @State private var themeManager = ThemeManager()
    @State private var favoritesViewModel = FavoritesViewModel()
    @State private var recentEntriesTracker = RecentEntriesTracker()
    @State private var showRegistration = false
    @State private var registrationViewModel: RegistrationViewModel?

    var body: some Scene {
        WindowGroup {
            contentView
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear { bootstrap() }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if let auth = authViewModel {
            if auth.isAuthenticated {
                if onboardingViewModel.shouldShowOnboarding && !onboardingViewModel.isOnboardingComplete {
                    OnboardingView(viewModel: onboardingViewModel)
                } else {
                    authenticatedView
                }
            } else if showRegistration, let regVM = registrationViewModel {
                if regVM.isRegistered {
                    // Registration complete — switch back to login flow
                    Color.clear.onAppear {
                        auth.isAuthenticated = true
                        showRegistration = false
                    }
                } else {
                    NavigationStack {
                        RegistrationView(viewModel: regVM) {
                            showRegistration = false
                        }
                    }
                }
            } else {
                NavigationStack {
                    VStack {
                        LoginView(viewModel: auth)
                        Button("Don't have an account? Register") {
                            showRegistration = true
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tint)
                        .font(.subheadline)
                        .padding(.bottom, 16)
                    }
                }
            }
        } else {
            ProgressView("Loading…")
        }
    }

    @ViewBuilder
    private var authenticatedView: some View {
        if let listVM = vaultListViewModel,
           let detailVM = vaultDetailViewModel,
           let entryVM = entryDetailViewModel {
            TabView {
                MainStackView(
                    router: router,
                    vaultListViewModel: listVM,
                    vaultDetailViewModel: detailVM,
                    entryDetailViewModel: entryVM,
                    keychainStore: keychain,
                    autoLockManager: autoLockManager,
                    recentEntriesTracker: recentEntriesTracker
                )
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button("Log Out") {
                            Task { await authViewModel?.logout() }
                        }
                    }
                }
                .tabItem {
                    Label("Vaults", systemImage: "lock.rectangle.stack")
                }

                NavigationStack {
                    FavoritesView(viewModel: favoritesViewModel) { favorite in
                        router.navigateToVault(favorite.vaultId)
                        router.navigateToEntry(favorite.entry.id)
                    }
                }
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
            }
        }
    }

    private func bootstrap() {
        let apiClient = APIClient(
            configuration: config,
            keychain: keychain
        )
        authViewModel = AuthViewModel(
            apiClient: apiClient,
            keychain: keychain
        )
        vaultListViewModel = VaultListViewModel(apiClient: apiClient)
        vaultDetailViewModel = VaultDetailViewModel(
            apiClient: apiClient,
            keychainStore: keychain,
            biometricAuthenticator: BiometricAuthenticator()
        )
        entryDetailViewModel = EntryDetailViewModel(apiClient: apiClient)
        registrationViewModel = RegistrationViewModel(
            apiClient: apiClient,
            keychain: keychain
        )
        Task { await authViewModel?.verifySession() }
    }
}

if #available(macOS 14.0, iOS 17.0, *) {
    BrightPassApp.main()
} else {
    print("BrightPass requires iOS 17.0 or later.")
}
