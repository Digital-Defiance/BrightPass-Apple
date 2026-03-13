import SwiftUI

/// A password generator view with length slider, character set toggles,
/// minimum count steppers, generate button, copy to clipboard, and
/// an optional "Use Password" action when accessed from an entry form.
///
/// **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7**
@available(macOS 14.0, iOS 17.0, *)
public struct PasswordGeneratorView: View {

    @Bindable var viewModel: PasswordGeneratorViewModel

    /// When non-nil, a "Use Password" button is shown that passes the
    /// generated password back to the calling entry form.
    private let onUsePassword: ((String) -> Void)?

    /// Called when the user dismisses the generator.
    private let onDismiss: (() -> Void)?

    @State private var showCopiedConfirmation = false

    // MARK: - Initializers

    /// Standalone usage (no "Use Password" action).
    public init(viewModel: PasswordGeneratorViewModel, onDismiss: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onUsePassword = nil
        self.onDismiss = onDismiss
    }

    /// Entry-form usage with "Use Password" callback.
    public init(
        viewModel: PasswordGeneratorViewModel,
        onUsePassword: @escaping (String) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onUsePassword = onUsePassword
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        Form {
            // Generated password display
            generatedPasswordSection

            // Length
            Section("Length") {
                HStack {
                    Slider(
                        value: lengthBinding,
                        in: 8...128,
                        step: 1
                    )
                    .accessibilityLabel("Password length")

                    Text("\(viewModel.length)")
                        .monospacedDigit()
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }

            // Character sets
            Section("Character Sets") {
                Toggle("Uppercase (A–Z)", isOn: $viewModel.includeUppercase)
                    .accessibilityLabel("Include uppercase letters")
                Toggle("Lowercase (a–z)", isOn: $viewModel.includeLowercase)
                    .accessibilityLabel("Include lowercase letters")
                Toggle("Digits (0–9)", isOn: $viewModel.includeDigits)
                    .accessibilityLabel("Include digits")
                Toggle("Special (!@#$…)", isOn: $viewModel.includeSpecial)
                    .accessibilityLabel("Include special characters")
            }

            // Minimum counts
            Section("Minimum Counts") {
                Stepper("Uppercase: \(viewModel.minUppercase)", value: $viewModel.minUppercase, in: 0...viewModel.length)
                    .accessibilityLabel("Minimum uppercase count")
                Stepper("Digits: \(viewModel.minDigits)", value: $viewModel.minDigits, in: 0...viewModel.length)
                    .accessibilityLabel("Minimum digit count")
                Stepper("Special: \(viewModel.minSpecial)", value: $viewModel.minSpecial, in: 0...viewModel.length)
                    .accessibilityLabel("Minimum special character count")
            }
        }
        .navigationTitle("Password Generator")
        .toolbar {
            if let onDismiss {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }

    // MARK: - Generated Password Section

    @ViewBuilder
    private var generatedPasswordSection: some View {
        Section {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .accessibilityLabel("Generating password")
                    Spacer()
                }
            } else if let password = viewModel.generatedPassword {
                Text(password)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .accessibilityLabel("Generated password")
            }

            if let error = viewModel.error {
                Text(error.userMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .accessibilityLabel("Error")
            }

            // Actions
            Button {
                Task { await viewModel.generate() }
            } label: {
                Label("Generate", systemImage: "arrow.clockwise")
            }
            .accessibilityLabel("Generate password")

            if let password = viewModel.generatedPassword {
                Button {
                    copyToClipboard(password)
                } label: {
                    Label(
                        showCopiedConfirmation ? "Copied" : "Copy to Clipboard",
                        systemImage: showCopiedConfirmation ? "checkmark" : "doc.on.doc"
                    )
                }
                .accessibilityLabel("Copy password to clipboard")

                if let onUsePassword {
                    Button {
                        onUsePassword(password)
                    } label: {
                        Label("Use Password", systemImage: "checkmark.circle")
                    }
                    .accessibilityLabel("Use this password in entry form")
                }
            }
        } header: {
            Text("Password")
        }
    }

    // MARK: - Helpers

    /// Bridges the `Int` length to a `Double` binding for `Slider`.
    private var lengthBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.length) },
            set: { viewModel.length = Int($0) }
        )
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        showCopiedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedConfirmation = false
        }
    }
}
