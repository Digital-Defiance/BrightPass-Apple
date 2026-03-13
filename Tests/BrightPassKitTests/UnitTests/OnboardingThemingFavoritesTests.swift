// Unit tests for onboarding, theming, and favorites
// Validates: Requirements 26.1, 26.3, 26.4, 27.1, 27.2, 27.3, 28.1, 28.2, 28.3

import XCTest
@testable import BrightPassKit

// MARK: - Helpers

private func freshDefaults() -> UserDefaults {
    let suite = "test.unit.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

private func makeEntry(_ title: String, type: EntryType = .login,
                        favorite: Bool = false) -> EntryPropertyRecord {
    EntryPropertyRecord(id: UUID().uuidString, title: title, type: type,
                        tags: [], url: nil, isFavorite: favorite)
}

// MARK: - Onboarding Tests

@available(macOS 14.0, iOS 17.0, *)
final class OnboardingUnitTests: XCTestCase {

    /// First launch: no key → shouldShowOnboarding is true.
    @MainActor
    func testFirstLaunchDetection() {
        let defaults = freshDefaults()
        let vm = OnboardingViewModel(defaults: defaults)
        XCTAssertTrue(vm.shouldShowOnboarding)
        XCTAssertFalse(vm.isOnboardingComplete)
        XCTAssertEqual(vm.currentStep, 0)
    }

    /// completeOnboarding() sets the flag.
    @MainActor
    func testCompleteOnboardingSetsFlag() {
        let defaults = freshDefaults()
        let vm = OnboardingViewModel(defaults: defaults)
        vm.completeOnboarding()
        XCTAssertFalse(vm.shouldShowOnboarding)
        XCTAssertTrue(vm.isOnboardingComplete)
        XCTAssertTrue(defaults.bool(forKey: "onboarding-complete"))
    }

    /// skip() also sets the flag.
    @MainActor
    func testSkipSetsFlag() {
        let defaults = freshDefaults()
        let vm = OnboardingViewModel(defaults: defaults)
        vm.skip()
        XCTAssertFalse(vm.shouldShowOnboarding)
        XCTAssertTrue(vm.isOnboardingComplete)
        XCTAssertTrue(defaults.bool(forKey: "onboarding-complete"))
    }

    /// nextStep() advances the step counter.
    @MainActor
    func testNextStepAdvances() {
        let defaults = freshDefaults()
        let vm = OnboardingViewModel(defaults: defaults)
        XCTAssertEqual(vm.currentStep, 0)
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 1)
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 2)
    }

    /// Flag persists across instances.
    @MainActor
    func testFlagPersistence() {
        let defaults = freshDefaults()
        let vm1 = OnboardingViewModel(defaults: defaults)
        vm1.completeOnboarding()

        let vm2 = OnboardingViewModel(defaults: defaults)
        XCTAssertFalse(vm2.shouldShowOnboarding)
        XCTAssertTrue(vm2.isOnboardingComplete)
    }
}

// MARK: - Theme Tests

@available(macOS 14.0, iOS 17.0, *)
final class ThemeUnitTests: XCTestCase {

    /// Default appearance is .system.
    @MainActor
    func testDefaultSystemAppearance() {
        let defaults = freshDefaults()
        let tm = ThemeManager(defaults: defaults)
        XCTAssertEqual(tm.selectedAppearance, .system)
        XCTAssertNil(tm.colorScheme)
    }

    /// Setting each mode persists and maps to correct colorScheme.
    @MainActor
    func testThemePersistenceAndColorSchemeMapping() {
        let defaults = freshDefaults()
        let tm = ThemeManager(defaults: defaults)

        tm.selectedAppearance = .light
        XCTAssertEqual(defaults.string(forKey: "appearance-mode"), "light")
        XCTAssertEqual(tm.colorScheme, .light)

        tm.selectedAppearance = .dark
        XCTAssertEqual(defaults.string(forKey: "appearance-mode"), "dark")
        XCTAssertEqual(tm.colorScheme, .dark)

        tm.selectedAppearance = .system
        XCTAssertEqual(defaults.string(forKey: "appearance-mode"), "system")
        XCTAssertNil(tm.colorScheme)
    }

    /// New ThemeManager reads persisted preference.
    @MainActor
    func testThemeReadsPersistedPreference() {
        let defaults = freshDefaults()
        let tm1 = ThemeManager(defaults: defaults)
        tm1.selectedAppearance = .dark

        let tm2 = ThemeManager(defaults: defaults)
        XCTAssertEqual(tm2.selectedAppearance, .dark)
        XCTAssertEqual(tm2.colorScheme, .dark)
    }
}


// MARK: - Favorites Tests

@available(macOS 14.0, iOS 17.0, *)
final class FavoritesUnitTests: XCTestCase {

    /// Favorites aggregation across multiple vaults.
    @MainActor
    func testFavoritesAggregationAcrossMultipleVaults() {
        let vm = FavoritesViewModel()
        let v1Entries = [
            makeEntry("Gmail", favorite: true),
            makeEntry("GitHub", favorite: false),
            makeEntry("Slack", favorite: true)
        ]
        let v2Entries = [
            makeEntry("AWS", favorite: true),
            makeEntry("Jira", favorite: false)
        ]
        vm.loadFavorites(from: [("vault1", v1Entries), ("vault2", v2Entries)])

        XCTAssertEqual(vm.favoriteEntries.count, 3)
        XCTAssertTrue(vm.favoriteEntries.allSatisfy(\.entry.isFavorite))
    }

    /// Empty vaults produce empty favorites.
    @MainActor
    func testFavoritesWithEmptyVaults() {
        let vm = FavoritesViewModel()
        vm.loadFavorites(from: [])
        XCTAssertTrue(vm.favoriteEntries.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }

    /// No unlocked vaults (empty input) produces empty favorites.
    @MainActor
    func testFavoritesWithNoUnlockedVaults() {
        let vm = FavoritesViewModel()
        vm.loadFavorites(from: [])
        XCTAssertTrue(vm.favoriteEntries.isEmpty)
    }

    /// Favorites navigation context includes correct vault ID.
    @MainActor
    func testFavoritesNavigationContextIncludesVaultId() {
        let vm = FavoritesViewModel()
        let entry1 = makeEntry("Entry1", favorite: true)
        let entry2 = makeEntry("Entry2", favorite: true)
        vm.loadFavorites(from: [("vaultA", [entry1]), ("vaultB", [entry2])])

        let favA = vm.favoriteEntries.first { $0.entry.id == entry1.id }
        XCTAssertEqual(favA?.vaultId, "vaultA")

        let favB = vm.favoriteEntries.first { $0.entry.id == entry2.id }
        XCTAssertEqual(favB?.vaultId, "vaultB")
    }

    /// Vaults with all non-favorite entries produce empty favorites.
    @MainActor
    func testVaultsWithNoFavorites() {
        let vm = FavoritesViewModel()
        let entries = [makeEntry("A"), makeEntry("B"), makeEntry("C")]
        vm.loadFavorites(from: [("v1", entries)])
        XCTAssertTrue(vm.favoriteEntries.isEmpty)
    }

    /// isLoading is false after loadFavorites completes.
    @MainActor
    func testIsLoadingFalseAfterLoad() {
        let vm = FavoritesViewModel()
        vm.loadFavorites(from: [("v1", [makeEntry("X", favorite: true)])])
        XCTAssertFalse(vm.isLoading)
    }
}
