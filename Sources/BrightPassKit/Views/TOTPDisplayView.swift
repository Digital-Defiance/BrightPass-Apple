import SwiftUI

/// Displays a 6-digit TOTP code with a countdown ring animation and copy action.
///
/// **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5**
@available(macOS 14.0, iOS 17.0, *)
public struct TOTPDisplayView: View {

    @Bindable var viewModel: TOTPViewModel

    /// The TOTP secret used to generate codes.
    private let secret: String

    /// Called when the user dismisses the view.
    private let onDismiss: (() -> Void)?

    public init(viewModel: TOTPViewModel, secret: String, onDismiss: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.secret = secret
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 20) {
            if viewModel.isLoading && viewModel.currentCode == nil {
                ProgressView("Generating code…")
                    .accessibilityLabel("Generating TOTP code")
            } else if let code = viewModel.currentCode {
                codeDisplay(code)
            }

            if let error = viewModel.error {
                Text(error.userMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Error")
            }
        }
        .padding()
        .task {
            await viewModel.startCodeGeneration(secret: secret)
        }
        .onDisappear {
            viewModel.stopCodeGeneration()
        }
    }

    // MARK: - Code Display

    @ViewBuilder
    private func codeDisplay(_ code: String) -> some View {
        ZStack {
            // Countdown ring
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                .frame(width: 100, height: 100)

            Circle()
                .trim(from: 0, to: countdownProgress)
                .stroke(countdownColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: viewModel.remainingSeconds)

            VStack(spacing: 4) {
                // 6-digit code with spacing for readability
                Text(formattedCode(code))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .accessibilityLabel("TOTP code \(code)")

                Text("\(viewModel.remainingSeconds)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("\(viewModel.remainingSeconds) seconds remaining")
            }
        }

        Button {
            if let code = viewModel.copyCode() {
                copyToClipboard(code)
            }
        } label: {
            Label("Copy Code", systemImage: "doc.on.doc")
        }
        .accessibilityLabel("Copy TOTP code")
    }

    // MARK: - Helpers

    /// Progress value for the countdown ring (1.0 = full, 0.0 = expired).
    private var countdownProgress: CGFloat {
        CGFloat(viewModel.remainingSeconds) / 30.0
    }

    /// Ring color shifts from green to orange to red as time runs out.
    private var countdownColor: Color {
        if viewModel.remainingSeconds > 10 {
            return .green
        } else if viewModel.remainingSeconds > 5 {
            return .orange
        } else {
            return .red
        }
    }

    /// Formats a 6-digit code as "123 456" for readability.
    private func formattedCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        let idx = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<idx]) \(code[idx...])"
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: text]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(30)
            ]
        )
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
