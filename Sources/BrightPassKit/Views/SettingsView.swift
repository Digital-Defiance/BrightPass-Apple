import SwiftUI

/// Settings view with auto-lock timeout, biometric toggle, appearance picker, and API environment picker.
@available(macOS 14.0, iOS 17.0, *)
public struct SettingsView: View {
    @Bindable var autoLockManager: AutoLockManager
    @Bindable var configurationManager: ConfigurationManager
    @Bindable var vaultDetailViewModel: VaultDetailViewModel
    @Bindable var themeManager: ThemeManager

    let currentVaultId: String?

    @State private var biometricEnabled: Bool = false
    @State private var biometricError: String?
    @State private var selectedEnvironment: ConfigurationManager.Environment = .development

    public init(autoLockManager: AutoLockManager,
                configurationManager: ConfigurationManager,
                vaultDetailViewModel: VaultDetailViewModel,
                themeManager: ThemeManager,
                currentVaultId: String?) {
        self.autoLockManager = autoLockManager
        self.configurationManager = configurationManager
        self.vaultDetailViewModel = vaultDetailViewModel
        self.themeManager = themeManager
        self.currentVaultId = currentVaultId
    }

    public var body: some View {
        Form {
            // Auto-lock timeout
            Section("Security") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-Lock Timeout: \(autoLockManager.timeoutMinutes) min")
                        .font(.subheadline)
                    Slider(
                        value: Binding(
                            get: { Double(autoLockManager.timeoutMinutes) },
                            set: { autoLockManager.timeoutMinutes = Int($0) }
                        ),
                        in: 1...60,
                        step: 1
                    )
                    .accessibilityLabel("Auto-lock timeout")
                    .accessibilityValue("\(autoLockManager.timeoutMinutes) minutes")
                    HStack {
                        Text("1 min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("60 min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Biometric toggle (only shown when a vault is selected)
                if let vaultId = currentVaultId {
                    Toggle("Biometric Unlock", isOn: $biometricEnabled)
                        .accessibilityLabel("Enable biometric unlock for this vault")
                        .onChange(of: biometricEnabled) { _, enabled in
                            toggleBiometric(vaultId: vaultId, enabled: enabled)
                        }

                    if let error = biometricError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Appearance
            Section("Appearance") {
                Picker("Theme", selection: $themeManager.selectedAppearance) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                .accessibilityLabel("Appearance mode")
            }

            // API environment
            Section("Developer") {
                Picker("API Environment", selection: $selectedEnvironment) {
                    Text("Development (localhost)").tag(ConfigurationManager.Environment.development)
                    Text("Production (brightchain.org)").tag(ConfigurationManager.Environment.production)
                }
                .accessibilityLabel("API environment")
                .onChange(of: selectedEnvironment) { _, env in
                    switch env {
                    case .development:
                        configurationManager.baseURL = URL(string: "http://localhost:8080")!
                    case .production:
                        configurationManager.baseURL = URL(string: "https://brightchain.org")!
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            if let vaultId = currentVaultId {
                biometricEnabled = vaultDetailViewModel.isBiometricEnabled(vaultId: vaultId)
            }
            // Infer current environment from baseURL
            if configurationManager.baseURL.host == "localhost" {
                selectedEnvironment = .development
            } else {
                selectedEnvironment = .production
            }
        }
    }

    private func toggleBiometric(vaultId: String, enabled: Bool) {
        biometricError = nil
        do {
            if enabled {
                // In a real flow, the user would provide their master password here.
                // For now, we enable with a placeholder — the actual hash would come
                // from the vault unlock flow.
                try vaultDetailViewModel.enableBiometric(vaultId: vaultId, masterPasswordHash: "")
            } else {
                try vaultDetailViewModel.disableBiometric(vaultId: vaultId)
            }
        } catch {
            biometricError = "Failed to update biometric setting."
            biometricEnabled = !enabled // revert
        }
    }
}

// MARK: - Environment Conformances

@available(macOS 14.0, iOS 17.0, *)
extension ConfigurationManager.Environment: Hashable {}
