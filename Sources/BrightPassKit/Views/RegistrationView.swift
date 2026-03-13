import SwiftUI

// MARK: - Password Strength Meter

/// Visual indicator for password strength, shown alongside the password field.
@available(macOS 14.0, iOS 17.0, *)
public struct PasswordStrengthMeterView: View {
    public let strength: PasswordStrengthLevel

    public init(strength: PasswordStrengthLevel) {
        self.strength = strength
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filledSegments ? color : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Password strength: \(label)")
    }

    private var filledSegments: Int {
        switch strength {
        case .weak: return 1
        case .fair: return 2
        case .good: return 3
        case .strong: return 4
        }
    }

    private var color: Color {
        switch strength {
        case .weak: return .red
        case .fair: return .orange
        case .good: return .yellow
        case .strong: return .green
        }
    }

    private var label: String {
        strength.rawValue.capitalized
    }
}


// MARK: - Registration View

/// Account registration with two steps: form entry, then mnemonic confirmation.
@available(macOS 14.0, iOS 17.0, *)
public struct RegistrationView: View {
    @Bindable var viewModel: RegistrationViewModel
    var onSwitchToLogin: (() -> Void)?

    public init(viewModel: RegistrationViewModel, onSwitchToLogin: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSwitchToLogin = onSwitchToLogin
    }

    public var body: some View {
        Group {
            if viewModel.generatedMnemonic != nil && !viewModel.hasSavedMnemonic {
                mnemonicConfirmationStep
            } else {
                registrationFormStep
            }
        }
    }

    // MARK: - Step 1: Registration Form

    private var registrationFormStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    BrightPassLogo()
                    Text("Create Account")
                        .font(.title2.bold())
                    Text("Set up your BrightPass account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                VStack(spacing: 16) {
                    // Username
                    fieldView(
                        label: "Username",
                        placeholder: "Choose a username",
                        text: $viewModel.username,
                        errorKey: "username",
                        contentType: .username
                    )

                    // Email
                    fieldView(
                        label: "Email",
                        placeholder: "Enter your email",
                        text: $viewModel.email,
                        errorKey: "email",
                        contentType: .emailAddress
                    )

                    // Password with strength meter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Create a password", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.isLoading)
                            .accessibilityLabel("Password")
                            #if os(iOS)
                            .textContentType(.newPassword)
                            #endif
                        if !viewModel.password.isEmpty {
                            PasswordStrengthMeterView(strength: viewModel.passwordStrength)
                        }
                        if let err = viewModel.fieldErrors["password"] {
                            Text(err)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    // Confirm Password
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Re-enter your password", text: $viewModel.confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .disabled(viewModel.isLoading)
                            .accessibilityLabel("Confirm password")
                            #if os(iOS)
                            .textContentType(.newPassword)
                            #endif
                        if let err = viewModel.fieldErrors["confirmPassword"] {
                            Text(err)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal, 32)

                // General error
                if let error = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error.userMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 32)
                }

                Spacer(minLength: 16)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        Task { await viewModel.register() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canRegister)
                    .accessibilityLabel("Create account")

                    Button("Already have an account? Log In") {
                        onSwitchToLogin?()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.tint)
                    .font(.subheadline)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .padding()
        }
        .onChange(of: viewModel.password) { _, _ in
            viewModel.evaluatePasswordStrength()
        }
    }

    // MARK: - Step 2: Mnemonic Confirmation

    private var mnemonicConfirmationStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Save Your Recovery Phrase")
                    .font(.title2.bold())
                Text("Write down these words and store them safely. You'll need them to log in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let mnemonic = viewModel.generatedMnemonic {
                mnemonicGrid(mnemonic)
                    .padding(.horizontal, 24)
            }

            if let error = viewModel.error {
                Text(error.userMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button("I Have Saved My Recovery Phrase") {
                viewModel.confirmMnemonicSaved()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .accessibilityLabel("Confirm recovery phrase saved")
        }
        .padding()
    }

    // MARK: - Helpers

    private var canRegister: Bool {
        !viewModel.username.isEmpty
        && !viewModel.email.isEmpty
        && !viewModel.password.isEmpty
        && !viewModel.confirmPassword.isEmpty
        && !viewModel.isLoading
    }

    private func fieldView(
        label: String,
        placeholder: String,
        text: Binding<String>,
        errorKey: String,
        contentType: ContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isLoading)
                .accessibilityLabel(label)
                #if os(iOS)
                .textContentType(contentType.uiContentType)
                .autocapitalization(.none)
                .keyboardType(contentType == .emailAddress ? .emailAddress : .default)
                #endif
            if let err = viewModel.fieldErrors[errorKey] {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func mnemonicGrid(_ mnemonic: String) -> some View {
        let words = mnemonic.split(separator: " ").map(String.init)
        return LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
        ], spacing: 12) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                HStack(spacing: 4) {
                    Text("\(index + 1).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    Text(word)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery phrase: \(mnemonic)")
    }

    /// Simple content type wrapper for cross-platform text field configuration.
    private enum ContentType {
        case username, emailAddress

        #if os(iOS)
        var uiContentType: UITextContentType {
            switch self {
            case .username: return .username
            case .emailAddress: return .emailAddress
            }
        }
        #endif
    }
}
