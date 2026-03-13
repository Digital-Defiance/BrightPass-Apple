import SwiftUI

/// Displays the full details of a vault entry with masked sensitive fields,
/// copy actions, and edit/delete controls.
@available(macOS 14.0, iOS 17.0, *)
public struct EntryDetailView: View {
    @Bindable var viewModel: EntryDetailViewModel

    let vaultId: String
    let onDeleted: () -> Void
    public var allEntries: [VaultEntry]

    @State private var showDeleteConfirmation = false
    @State private var duplicateResult: DuplicatePasswordResult?
    @State private var showDuplicateEntries = false
    @State private var currentDuplicateResult: DuplicatePasswordResult?

    public init(viewModel: EntryDetailViewModel, vaultId: String, onDeleted: @escaping () -> Void, allEntries: [VaultEntry] = []) {
        self.viewModel = viewModel
        self.vaultId = vaultId
        self.onDeleted = onDeleted
        self.allEntries = allEntries
    }

    public var body: some View {
        Group {
            if let entry = viewModel.entry {
                entryContent(entry)
            } else if viewModel.isLoading {
                ProgressView("Loading entry…")
            } else {
                ContentUnavailableView("No Entry", systemImage: "doc.text",
                                       description: Text("Entry could not be loaded."))
            }
        }
        .navigationTitle(viewModel.entry?.title ?? "Entry")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(viewModel.entry == nil)
            }
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteEntry(vaultId: vaultId)
                    if viewModel.entry == nil && viewModel.error == nil {
                        onDeleted()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.error {
                Text(error.userMessage)
            }
        }
        .sheet(isPresented: $showDuplicateEntries) {
            if let dupResult = currentDuplicateResult {
                DuplicateEntriesListView(
                    duplicateEntryIds: dupResult.duplicateEntryIds,
                    allEntries: allEntries
                )
            }
        }
    }

    // MARK: - Entry Content

    @ViewBuilder
    private func entryContent(_ entry: VaultEntry) -> some View {
        List {
            // Header section
            Section {
                HStack {
                    Image(systemName: iconName(for: entry.type))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.headline)
                        Text(entry.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorite")
                    }
                }
            }

            // Type-specific fields
            switch entry.fields {
            case .login(let fields):
                loginFieldsSection(fields)
            case .secureNote(let fields):
                secureNoteSection(fields)
            case .creditCard(let fields):
                creditCardSection(fields)
            case .identityDocument(let fields):
                identityDocumentSection(fields)
            }

            // Tags
            if !entry.tags.isEmpty {
                Section("Tags") {
                    FlowTagsView(tags: entry.tags)
                }
            }

            // Metadata
            Section("Details") {
                LabeledContent("Created", value: entry.createdAt, format: .dateTime)
                LabeledContent("Updated", value: entry.updatedAt, format: .dateTime)
            }

            // Delete
            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Entry", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Login Fields

    @ViewBuilder
    private func loginFieldsSection(_ fields: LoginFields) -> some View {
        Section("Login Details") {
            if !fields.siteURL.isEmpty {
                LabeledContent("Website", value: fields.siteURL)
            }
            LabeledContent("Username", value: fields.username)

            HStack {
                LabeledContent("Password") {
                    Text(viewModel.isPasswordVisible ? fields.password : "••••••••")
                        .font(.body.monospaced())
                }
                Spacer()
                Button {
                    viewModel.togglePasswordVisibility()
                } label: {
                    Image(systemName: viewModel.isPasswordVisible ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(viewModel.isPasswordVisible ? "Hide password" : "Show password")

                Button {
                    copyToClipboard(fields.password)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy password")
            }

            if let totp = fields.totpSecret, !totp.isEmpty {
                HStack {
                    LabeledContent("TOTP Secret") {
                        Text(viewModel.isPasswordVisible ? totp : "••••••••")
                            .font(.body.monospaced())
                    }
                    Spacer()
                    Button {
                        copyToClipboard(totp)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Copy TOTP secret")
                }
            }

            if let entry = viewModel.entry {
                let dupResult = DuplicatePasswordDetector.detect(
                    entryId: entry.id,
                    password: fields.password,
                    allEntries: allEntries
                )
                if dupResult.isDuplicate {
                    DuplicatePasswordWarningView(result: dupResult) {
                        currentDuplicateResult = dupResult
                        showDuplicateEntries = true
                    }
                }
            }
        }
    }

    // MARK: - Secure Note

    @ViewBuilder
    private func secureNoteSection(_ fields: SecureNoteFields) -> some View {
        Section("Note") {
            Text(fields.content)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    // MARK: - Credit Card

    @ViewBuilder
    private func creditCardSection(_ fields: CreditCardFields) -> some View {
        Section("Card Details") {
            LabeledContent("Cardholder", value: fields.cardholderName)

            HStack {
                LabeledContent("Card Number") {
                    Text(viewModel.isPasswordVisible ? fields.cardNumber : maskedCardNumber(fields.cardNumber))
                        .font(.body.monospaced())
                }
                Spacer()
                Button {
                    viewModel.togglePasswordVisibility()
                } label: {
                    Image(systemName: viewModel.isPasswordVisible ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(viewModel.isPasswordVisible ? "Hide card details" : "Show card details")

                Button {
                    copyToClipboard(fields.cardNumber)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy card number")
            }

            LabeledContent("Expiration", value: fields.expirationDate)

            HStack {
                LabeledContent("CVV") {
                    Text(viewModel.isPasswordVisible ? fields.cvv : "•••")
                        .font(.body.monospaced())
                }
                Spacer()
                Button {
                    copyToClipboard(fields.cvv)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy CVV")
            }
        }
    }

    // MARK: - Identity Document

    @ViewBuilder
    private func identityDocumentSection(_ fields: IdentityDocumentFields) -> some View {
        Section("Identity Details") {
            LabeledContent("Name", value: fields.name)
            LabeledContent("Email", value: fields.email)
            LabeledContent("Phone", value: fields.phone)
            LabeledContent("Address", value: fields.address)
        }

        if !fields.customFields.isEmpty {
            Section("Custom Fields") {
                ForEach(fields.customFields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    LabeledContent(key, value: value)
                }
            }
        }
    }

    // MARK: - Helpers

    private func iconName(for type: EntryType) -> String {
        switch type {
        case .login: return "person.crop.circle"
        case .secureNote: return "note.text"
        case .creditCard: return "creditcard"
        case .identityDocument: return "person.text.rectangle"
        }
    }

    private func maskedCardNumber(_ number: String) -> String {
        guard number.count >= 4 else { return "••••" }
        let lastFour = String(number.suffix(4))
        return "•••• •••• •••• \(lastFour)"
    }

    private func copyToClipboard(_ value: String) {
        #if os(iOS)
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: value]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(30)
            ]
        )
        #else
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        #endif
    }
}

// MARK: - Tags Flow Layout

@available(macOS 14.0, iOS 17.0, *)
struct FlowTagsView: View {
    let tags: [String]

    var body: some View {
        // Simple wrapping layout using horizontal scroll for simplicity
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tags: \(tags.joined(separator: ", "))")
    }
}

// MARK: - Duplicate Entries List

@available(macOS 14.0, iOS 17.0, *)
struct DuplicateEntriesListView: View {
    let duplicateEntryIds: [String]
    let allEntries: [VaultEntry]
    @Environment(\.dismiss) private var dismiss

    private var duplicateEntries: [VaultEntry] {
        allEntries.filter { duplicateEntryIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(duplicateEntries) { entry in
                HStack {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.body)
                        if case .login(let fields) = entry.fields {
                            Text(fields.username)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Duplicate Passwords")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if duplicateEntries.isEmpty {
                    ContentUnavailableView("No Duplicates", systemImage: "checkmark.shield",
                                           description: Text("No other entries share this password."))
                }
            }
        }
    }
}
