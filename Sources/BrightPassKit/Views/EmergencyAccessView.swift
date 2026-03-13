import SwiftUI

/// Displays emergency access configuration and recovery controls.
///
/// Shows the current config (share count, threshold, trustees), a form to configure
/// new settings, and a recovery section to input shares.
///
/// **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7**
@available(macOS 14.0, iOS 17.0, *)
public struct EmergencyAccessView: View {

    @Bindable var viewModel: EmergencyAccessViewModel

    private let vaultId: String
    private let onDismiss: (() -> Void)?

    @State private var totalShares: Int = 5
    @State private var threshold: Int = 3
    @State private var shareInputs: [String] = [""]
    @State private var isRecoveryMode: Bool = false

    public init(viewModel: EmergencyAccessViewModel, vaultId: String, onDismiss: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.vaultId = vaultId
        self.onDismiss = onDismiss
    }

    public var body: some View {
        List {
            currentConfigSection
            if isRecoveryMode {
                recoverySection
            } else {
                configureSection
            }
        }
        .navigationTitle("Emergency Access")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isRecoveryMode ? "Configure" : "Recover") {
                    isRecoveryMode.toggle()
                }
                .accessibilityLabel(isRecoveryMode ? "Switch to configuration" : "Switch to recovery")
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .accessibilityLabel("Loading emergency access")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.userMessage)
            }
        }
        .task {
            await viewModel.loadConfig(vaultId: vaultId)
        }
    }

    // MARK: - Current Config

    private var currentConfigSection: some View {
        Section("Current Configuration") {
            if let config = viewModel.config {
                LabeledContent("Total Shares", value: "\(config.totalShares)")
                LabeledContent("Threshold", value: "\(config.threshold)")
                if !config.trustees.isEmpty {
                    ForEach(config.trustees, id: \.self) { trustee in
                        Text(trustee)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !viewModel.isLoading {
                Text("No emergency access configured")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Configure

    private var configureSection: some View {
        Section("Configure") {
            Stepper("Total Shares: \(totalShares)", value: $totalShares, in: 2...20)
                .accessibilityLabel("Total number of shares")
            Stepper("Threshold: \(threshold)", value: $threshold, in: 2...totalShares)
                .accessibilityLabel("Minimum shares required for recovery")

            Button("Save Configuration") {
                Task {
                    await viewModel.configure(vaultId: vaultId, totalShares: totalShares, threshold: threshold)
                }
            }
            .accessibilityLabel("Save emergency access configuration")
        }
    }

    // MARK: - Recovery

    private var recoverySection: some View {
        Section("Recovery") {
            ForEach(shareInputs.indices, id: \.self) { index in
                TextField("Share \(index + 1)", text: $shareInputs[index])
                    .accessibilityLabel("Recovery share \(index + 1)")
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }

            HStack {
                Button("Add Share") {
                    shareInputs.append("")
                }
                .accessibilityLabel("Add another recovery share")

                Spacer()

                if shareInputs.count > 1 {
                    Button("Remove Last", role: .destructive) {
                        shareInputs.removeLast()
                    }
                    .accessibilityLabel("Remove last recovery share")
                }
            }

            Button("Recover Vault") {
                Task {
                    let nonEmpty = shareInputs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    await viewModel.recover(vaultId: vaultId, shares: nonEmpty)
                }
            }
            .disabled(shareInputs.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .accessibilityLabel("Attempt vault recovery with provided shares")

            if viewModel.recoveredVault != nil {
                Label("Vault recovered successfully", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
