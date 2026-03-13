import Foundation

/// Manages onboarding state: step progression, skip, and completion persistence via UserDefaults.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class OnboardingViewModel {

    public var currentStep: Int = 0
    public var isOnboardingComplete: Bool = false

    private let defaults: UserDefaults
    private static let key = "onboarding-complete"

    public var shouldShowOnboarding: Bool {
        !defaults.bool(forKey: Self.key)
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isOnboardingComplete = defaults.bool(forKey: Self.key)
    }

    public func nextStep() {
        currentStep += 1
    }

    public func skip() {
        markComplete()
    }

    public func completeOnboarding() {
        markComplete()
    }

    private func markComplete() {
        defaults.set(true, forKey: Self.key)
        isOnboardingComplete = true
    }
}
