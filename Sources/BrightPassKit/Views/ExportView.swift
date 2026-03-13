import SwiftUI

/// Export view with format picker and platform-specific save/share.
@available(macOS 14.0, iOS 17.0, *)
public struct ExportView: View {
    @Bindable var viewModel: ExportViewModel
    let vaultId: String

    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ExportViewModel, vaultId: String) {
        self.viewModel = viewModel
        self.vaultId = vaultId
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $viewModel.selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue.uppercased()).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Export format")
                }

                Section {
                    Button {
                        Task {
                            await viewModel.exportEntries(vaultId: vaultId)
                            if viewModel.exportedData != nil {
                                presentExport()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Export entries")
                }

                if let error = viewModel.error {
                    Section {
                        Text(error.userMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Export Entries")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            #endif
        }
    }

    private func presentExport() {
        #if os(iOS)
        showShareSheet = true
        #else
        presentSavePanel()
        #endif
    }

    #if os(macOS)
    private func presentSavePanel() {
        guard let data = viewModel.exportedData else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = viewModel.selectedFormat == .csv
            ? [.commaSeparatedText]
            : [.json]
        panel.nameFieldStringValue = "brightpass-export.\(viewModel.selectedFormat.rawValue)"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }
    #endif
}
