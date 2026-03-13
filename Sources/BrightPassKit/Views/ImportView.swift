import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Displays import source selection, file picker, and result summary.
///
/// **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**
@available(macOS 14.0, iOS 17.0, *)
public struct ImportView: View {

    @Bindable var viewModel: ImportViewModel

    private let vaultId: String
    private let onDismiss: (() -> Void)?

    @State private var selectedSource: ImportSource = .onePasswordCSV
    @State private var showFilePicker: Bool = false
    @State private var importedFileData: Data?

    public init(viewModel: ImportViewModel, vaultId: String, onDismiss: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.vaultId = vaultId
        self.onDismiss = onDismiss
    }

    public var body: some View {
        List {
            sourceSelectionSection
            importActionSection
            resultSection
        }
        .navigationTitle("Import")
        .overlay {
            if viewModel.isLoading {
                ProgressView("Importing…")
                    .accessibilityLabel("Importing entries")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.userMessage)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data, .commaSeparatedText, .json, .xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    importedFileData = try? Data(contentsOf: url)
                }
            case .failure:
                break
            }
        }
    }

    // MARK: - Source Selection

    private var sourceSelectionSection: some View {
        Section("Source") {
            Picker("Import From", selection: $selectedSource) {
                Text("1Password (CSV)").tag(ImportSource.onePasswordCSV)
                Text("1Password (1PUX)").tag(ImportSource.onePassword1PUX)
                Text("LastPass (CSV)").tag(ImportSource.lastPassCSV)
                Text("Bitwarden (JSON)").tag(ImportSource.bitwardenJSON)
                Text("Bitwarden (CSV)").tag(ImportSource.bitwardenCSV)
                Text("Chrome (CSV)").tag(ImportSource.chromeCSV)
                Text("Firefox (CSV)").tag(ImportSource.firefoxCSV)
                Text("KeePass (XML)").tag(ImportSource.keepassXML)
                Text("Dashlane (JSON)").tag(ImportSource.dashlaneJSON)
            }
            .accessibilityLabel("Password manager source")
        }
    }

    // MARK: - Import Action

    private var importActionSection: some View {
        Section {
            Button("Select File…") {
                showFilePicker = true
            }
            .accessibilityLabel("Select file to import")

            if importedFileData != nil {
                Label("File selected", systemImage: "doc.fill")
                    .foregroundStyle(.secondary)

                Button("Import") {
                    guard let data = importedFileData else { return }
                    Task {
                        await viewModel.importFile(vaultId: vaultId, source: selectedSource, fileData: data)
                    }
                }
                .accessibilityLabel("Start import")
            }
        }
    }

    // MARK: - Result Summary

    @ViewBuilder
    private var resultSection: some View {
        if let result = viewModel.result {
            Section("Result") {
                LabeledContent("Imported", value: "\(result.importedCount) entries")

                if !result.errors.isEmpty {
                    ForEach(result.errors, id: \.self) { errorMsg in
                        Label(errorMsg, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Label("All entries imported successfully", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }
}
