import SwiftUI

/// Multi-step onboarding flow shown on first launch after login/registration.
@available(macOS 14.0, iOS 17.0, *)
public struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    private let steps: [(icon: String, title: String, description: String)] = [
        ("lock.shield.fill", "Welcome to BrightPass",
         "Your secure password manager for iOS and macOS. All your credentials, encrypted and synced."),
        ("plus.rectangle.on.folder.fill", "Create a Vault",
         "Organize your credentials into vaults. Each vault is protected by its own master password."),
        ("key.fill", "Add Your First Entry",
         "Store logins, secure notes, credit cards, and identity documents — all in one place.")
    ]

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Step content
            if viewModel.currentStep < steps.count {
                let step = steps[viewModel.currentStep]
                VStack(spacing: 16) {
                    BrightPassLogo()
                    Text(step.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(step.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .accessibilityElement(children: .combine)
            }

            Spacer()

            // Step indicators
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index == viewModel.currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 24)

            // Actions
            VStack(spacing: 12) {
                if viewModel.currentStep < steps.count - 1 {
                    Button("Continue") {
                        withAnimation { viewModel.nextStep() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Get Started") {
                        viewModel.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button("Skip") {
                    viewModel.skip()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .padding()
    }
}
