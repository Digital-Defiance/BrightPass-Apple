import SwiftUI

/// Login view with mnemonic input, validation feedback, and ECIES direct challenge auth.
@available(macOS 14.0, iOS 17.0, *)
public struct LoginView: View {
    @Bindable var viewModel: AuthViewModel

    @State private var wordCount: Int = 0

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                BrightPassLogo()
                Text("Enter your credentials to log in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            // Form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username / Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter your username or email", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel("Username or email")
                        #if os(iOS)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        #endif
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Recovery Phrase")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(wordCount) words")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    TextEditor(text: $viewModel.mnemonic)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(mnemonicBorderColor, lineWidth: 1)
                        )
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel("Recovery phrase (12 or 24 words)")
                }

                // Validation feedback
                if !viewModel.mnemonic.isEmpty {
                    HStack {
                        Image(systemName: viewModel.isMnemonicValid ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(viewModel.isMnemonicValid ? .green : .orange)
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(viewModel.isMnemonicValid ? .green : .orange)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 32)

            // Error
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

            Spacer()

            // Login button
            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.login() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canLogin)
                .accessibilityLabel("Log in")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .padding()
        .onChange(of: viewModel.mnemonic) { _, _ in
            updateWordCount()
            viewModel.validateMnemonic()
        }
        .onAppear { updateWordCount() }
    }

    private var canLogin: Bool {
        !viewModel.username.isEmpty && viewModel.isMnemonicValid && !viewModel.isLoading
    }

    private var mnemonicBorderColor: Color {
        if viewModel.mnemonic.isEmpty { return Color.secondary.opacity(0.3) }
        return viewModel.isMnemonicValid ? .green : .orange
    }

    private var validationMessage: String {
        if viewModel.isMnemonicValid { return "Valid recovery phrase" }
        if wordCount < 12 { return "Enter \(12 - wordCount) more word\(12 - wordCount == 1 ? "" : "s") (12 or 24 total)" }
        if wordCount > 12 && wordCount < 24 { return "Enter \(24 - wordCount) more word\(24 - wordCount == 1 ? "" : "s") for a 24-word phrase" }
        if wordCount > 24 { return "Too many words (\(wordCount))" }
        return "Invalid recovery phrase"
    }

    private func updateWordCount() {
        wordCount = viewModel.mnemonic
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ").count
    }
}
