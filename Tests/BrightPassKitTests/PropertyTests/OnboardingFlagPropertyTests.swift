// Property 34: Onboarding Flag Round-Trip
// Validates: Requirements 26.1, 26.4
//
// When the "onboarding-complete" key is absent from UserDefaults,
// `shouldShowOnboarding` returns true. After `completeOnboarding()` or
// `skip()`, the key is set and `shouldShowOnboarding` returns false.

import XCTest
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class OnboardingFlagPropertyTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let suite = "test.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Property 34: When the key is absent, shouldShowOnboarding is true.
    /// After completeOnboarding() or skip(), shouldShowOnboarding is false.
    @MainActor
    func testOnboardingFlagRoundTrip() {
        for i in 0..<200 {
            let defaults = freshDefaults()

            // Key absent → should show onboarding
            let vm = OnboardingViewModel(defaults: defaults)
            XCTAssertTrue(vm.shouldShowOnboarding,
                          "Iteration \(i): shouldShowOnboarding must be true when key is absent")
            XCTAssertFalse(vm.isOnboardingComplete,
                           "Iteration \(i): isOnboardingComplete must be false initially")

            // Randomly choose completeOnboarding() or skip()
            if Bool.random() {
                vm.completeOnboarding()
            } else {
                vm.skip()
            }

            XCTAssertFalse(vm.shouldShowOnboarding,
                           "Iteration \(i): shouldShowOnboarding must be false after completion/skip")
            XCTAssertTrue(vm.isOnboardingComplete,
                          "Iteration \(i): isOnboardingComplete must be true after completion/skip")

            // A new view model reading the same defaults should also see false
            let vm2 = OnboardingViewModel(defaults: defaults)
            XCTAssertFalse(vm2.shouldShowOnboarding,
                           "Iteration \(i): new VM must read persisted flag as false")
        }
    }

    /// Verify nextStep() does not affect the onboarding-complete flag.
    @MainActor
    func testNextStepDoesNotCompleteOnboarding() {
        let defaults = freshDefaults()
        let vm = OnboardingViewModel(defaults: defaults)

        for _ in 0..<10 {
            vm.nextStep()
        }

        XCTAssertTrue(vm.shouldShowOnboarding,
                       "nextStep() must not set the onboarding-complete flag")
        XCTAssertFalse(vm.isOnboardingComplete)
    }
}
