import SwiftUI

/// A type-specific entry creation and editing form.
///
/// Presents fields appropriate to the selected `EntryType`:
/// - Login: site URL, username, password, optional TOTP secret, tags, favorite
/// - Credit card: cardholder name, card number, expiration, CVV, tags, favorite
/// - Secure note: title, encrypted text content, tags, favorite
/// - Identity document: name, email, phone, address, custom fields, tags, favorite
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**
@available(macOS 14.0, iOS 17.0, *)
public struct EntryFormView: View {

    // MARK: - Shared State

    @State private var title: String
    @State private var entryType: EntryType
    @State private var tags: [String]
    @State private var isFavorite: Bool
    @State private var tagInput: String = ""

    // MARK: - Login Fields

    @State private var siteURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var totpSecret: String = ""

    // MARK: - Credit Card Fields

    @State private var cardholderName: String = ""
    @State private var cardNumber: String = ""
    @State private var expirationDate: String = ""
    @State private var cvv: String = ""

    // MARK: - Secure Note Fields

    @State private var noteContent: String = ""

    // MARK: - Identity Document Fields

    @State private var idName: String = ""
    @State private var idEmail: String = ""
    @State private var idPhone: String = ""
    @State private var idAddress: String = ""
    @State private var customFields: [CustomFieldEntry] = []
    @State private var newCustomFieldKey: String = ""
    @State private var newCustomFieldValue: String = ""

    // MARK: - Configuration

    private let isNewEntry: Bool
    private let onSave: (VaultEntry) -> Void
    private let onCancel: () -> Void

    /// A helper type for managing custom field key-value pairs in the identity form.
    struct CustomFieldEntry: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    // MARK: - Initializers

    /// Creates a form for a new entry of the given type.
    public init(
        entryType: EntryType,
        onSave: @escaping (VaultEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.isNewEntry = true
        self.onSave = onSave
        self.onCancel = onCancel
        _entryType = State(initialValue: entryType)
        _title = State(initialValue: "")
        _tags = State(initialValue: [])
        _isFavorite = State(initialValue: false)
    }

    /// Creates a form pre-populated with an existing entry for editing.
    public init(
        entry: VaultEntry,
        onSave: @escaping (VaultEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.isNewEntry = false
        self.onSave = onSave
        self.onCancel = onCancel
        _entryType = State(initialValue: entry.type)
        _title = State(initialValue: entry.title)
        _tags = State(initialValue: entry.tags)
        _isFavorite = State(initialValue: entry.isFavorite)

        switch entry.fields {
        case .login(let fields):
            _siteURL = State(initialValue: fields.siteURL)
            _username = State(initialValue: fields.username)
            _password = State(initialValue: fields.password)
            _totpSecret = State(initialValue: fields.totpSecret ?? "")
        case .creditCard(let fields):
            _cardholderName = State(initialValue: fields.cardholderName)
            _cardNumber = State(initialValue: fields.cardNumber)
            _expirationDate = State(initialValue: fields.expirationDate)
            _cvv = State(initialValue: fields.cvv)
        case .secureNote(let fields):
            _noteContent = State(initialValue: fields.content)
        case .identityDocument(let fields):
            _idName = State(initialValue: fields.name)
            _idEmail = State(initialValue: fields.email)
            _idPhone = State(initialValue: fields.phone)
            _idAddress = State(initialValue: fields.address)
            _customFields = State(initialValue: fields.customFields.sorted(by: { $0.key < $1.key }).map {
                CustomFieldEntry(key: $0.key, value: $0.value)
            })
        }
    }

    // MARK: - Body

    public var body: some View {
        Form {
            // Entry type selector (only for new entries)
            if isNewEntry {
                Section("Entry Type") {
                    Picker("Type", selection: $entryType) {
                        ForEach(EntryType.allCases, id: \.self) { type in
                            Label(displayName(for: type), systemImage: iconName(for: type))
                                .tag(type)
                        }
                    }
                    .accessibilityLabel("Entry type")
                }
            }

            // Title
            Section("Title") {
                TextField("Entry title", text: $title)
                    .accessibilityLabel("Entry title")
            }

            // Type-specific fields
            switch entryType {
            case .login:
                loginFormSection
            case .creditCard:
                creditCardFormSection
            case .secureNote:
                secureNoteFormSection
            case .identityDocument:
                identityDocumentFormSection
            }

            // Tags
            tagsSection

            // Favorite
            Section {
                Toggle("Favorite", isOn: $isFavorite)
                    .accessibilityLabel("Mark as favorite")
            }
        }
        .navigationTitle(isNewEntry ? "New Entry" : "Edit Entry")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(buildEntry())
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Login Form

    @ViewBuilder
    private var loginFormSection: some View {
        Section("Login Details") {
            TextField("Site URL", text: $siteURL)
                .accessibilityLabel("Site URL")
                #if os(iOS)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocapitalization(.none)
                #endif

            TextField("Username", text: $username)
                .accessibilityLabel("Username")
                #if os(iOS)
                .textContentType(.username)
                .autocapitalization(.none)
                #endif

            SecureField("Password", text: $password)
                .accessibilityLabel("Password")
                #if os(iOS)
                .textContentType(.password)
                #endif

            if !password.isEmpty {
                PasswordStrengthMeterView(strength: PasswordStrengthEvaluator.evaluate(password))
            }

            TextField("TOTP Secret (optional)", text: $totpSecret)
                .accessibilityLabel("TOTP secret")
                #if os(iOS)
                .autocapitalization(.none)
                #endif
        }
    }

    // MARK: - Credit Card Form

    @ViewBuilder
    private var creditCardFormSection: some View {
        Section("Card Details") {
            TextField("Cardholder Name", text: $cardholderName)
                .accessibilityLabel("Cardholder name")
                #if os(iOS)
                .textContentType(.name)
                #endif

            TextField("Card Number", text: $cardNumber)
                .accessibilityLabel("Card number")
                #if os(iOS)
                .keyboardType(.numberPad)
                .textContentType(.creditCardNumber)
                #endif

            TextField("Expiration Date (MM/YY)", text: $expirationDate)
                .accessibilityLabel("Expiration date")

            SecureField("CVV", text: $cvv)
                .accessibilityLabel("CVV")
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        }
    }

    // MARK: - Secure Note Form

    @ViewBuilder
    private var secureNoteFormSection: some View {
        Section("Note Content") {
            TextEditor(text: $noteContent)
                .frame(minHeight: 120)
                .accessibilityLabel("Note content")
        }
    }

    // MARK: - Identity Document Form

    @ViewBuilder
    private var identityDocumentFormSection: some View {
        Section("Identity Details") {
            TextField("Full Name", text: $idName)
                .accessibilityLabel("Full name")
                #if os(iOS)
                .textContentType(.name)
                #endif

            TextField("Email", text: $idEmail)
                .accessibilityLabel("Email")
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                #endif

            TextField("Phone", text: $idPhone)
                .accessibilityLabel("Phone number")
                #if os(iOS)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                #endif

            TextField("Address", text: $idAddress)
                .accessibilityLabel("Address")
                #if os(iOS)
                .textContentType(.fullStreetAddress)
                #endif
        }

        Section("Custom Fields") {
            ForEach($customFields) { $field in
                HStack {
                    TextField("Key", text: $field.key)
                        .accessibilityLabel("Custom field key")
                    TextField("Value", text: $field.value)
                        .accessibilityLabel("Custom field value")
                }
            }
            .onDelete { indices in
                customFields.remove(atOffsets: indices)
            }

            HStack {
                TextField("New key", text: $newCustomFieldKey)
                    .accessibilityLabel("New custom field key")
                TextField("New value", text: $newCustomFieldValue)
                    .accessibilityLabel("New custom field value")
                Button {
                    guard !newCustomFieldKey.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    customFields.append(CustomFieldEntry(key: newCustomFieldKey, value: newCustomFieldValue))
                    newCustomFieldKey = ""
                    newCustomFieldValue = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(newCustomFieldKey.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add custom field")
            }
        }
    }

    // MARK: - Tags Section

    @ViewBuilder
    private var tagsSection: some View {
        Section("Tags") {
            if !tags.isEmpty {
                FlowTagsView(tags: tags)
                ForEach(tags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Spacer()
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove tag \(tag)")
                    }
                }
            }

            HStack {
                TextField("Add tag", text: $tagInput)
                    .accessibilityLabel("New tag")
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                    .onSubmit {
                        addTag()
                    }
                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add tag")
            }
        }
    }

    // MARK: - Helpers

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    private func buildEntry() -> VaultEntry {
        let fields: EntryFields
        switch entryType {
        case .login:
            fields = .login(LoginFields(
                siteURL: siteURL,
                username: username,
                password: password,
                totpSecret: totpSecret.isEmpty ? nil : totpSecret
            ))
        case .creditCard:
            fields = .creditCard(CreditCardFields(
                cardholderName: cardholderName,
                cardNumber: cardNumber,
                expirationDate: expirationDate,
                cvv: cvv
            ))
        case .secureNote:
            fields = .secureNote(SecureNoteFields(
                content: noteContent
            ))
        case .identityDocument:
            var cfDict: [String: String] = [:]
            for field in customFields where !field.key.trimmingCharacters(in: .whitespaces).isEmpty {
                cfDict[field.key] = field.value
            }
            fields = .identityDocument(IdentityDocumentFields(
                name: idName,
                email: idEmail,
                phone: idPhone,
                address: idAddress,
                customFields: cfDict
            ))
        }

        let now = Date()
        return VaultEntry(
            id: UUID().uuidString,
            type: entryType,
            title: title,
            fields: fields,
            tags: tags,
            isFavorite: isFavorite,
            createdAt: now,
            updatedAt: now
        )
    }

    private func displayName(for type: EntryType) -> String {
        switch type {
        case .login: return "Login"
        case .secureNote: return "Secure Note"
        case .creditCard: return "Credit Card"
        case .identityDocument: return "Identity Document"
        }
    }

    private func iconName(for type: EntryType) -> String {
        switch type {
        case .login: return "person.crop.circle"
        case .secureNote: return "note.text"
        case .creditCard: return "creditcard"
        case .identityDocument: return "person.text.rectangle"
        }
    }
}
