import SwiftUI

/// Displays the entries within an unlocked vault with search bar, type filter chips,
/// and a favorites toggle. Supports entry selection and deletion.
@available(macOS 14.0, iOS 17.0, *)
public struct VaultDetailView: View {
    @Bindable var viewModel: VaultDetailViewModel
    @Bindable var sortViewModel: EntrySortViewModel
    var recentEntriesTracker: RecentEntriesTracker?
    var vaultListViewModel: VaultListViewModel?
    var masterPasswordChangeViewModel: MasterPasswordChangeViewModel?
    var vaultRenameViewModel: VaultRenameViewModel?
    var exportViewModel: ExportViewModel?

    let onSelectEntry: (EntryPropertyRecord) -> Void

    @State private var entryToDelete: EntryPropertyRecord?
    @State private var showRecentEntries = true
    @State private var showChangePassword = false
    @State private var showRename = false
    @State private var showExport = false
    @State private var showNewEntry = false
    @State private var newEntryType: EntryType = .login

    public init(
        viewModel: VaultDetailViewModel,
        sortViewModel: EntrySortViewModel,
        recentEntriesTracker: RecentEntriesTracker? = nil,
        vaultListViewModel: VaultListViewModel? = nil,
        masterPasswordChangeViewModel: MasterPasswordChangeViewModel? = nil,
        vaultRenameViewModel: VaultRenameViewModel? = nil,
        exportViewModel: ExportViewModel? = nil,
        onSelectEntry: @escaping (EntryPropertyRecord) -> Void
    ) {
        self.viewModel = viewModel
        self.sortViewModel = sortViewModel
        self.recentEntriesTracker = recentEntriesTracker
        self.vaultListViewModel = vaultListViewModel
        self.masterPasswordChangeViewModel = masterPasswordChangeViewModel
        self.vaultRenameViewModel = vaultRenameViewModel
        self.exportViewModel = exportViewModel
        self.onSelectEntry = onSelectEntry
    }

    private var filteredEntries: [EntryPropertyRecord] {
        sortViewModel.sortEntries(viewModel.filterEntries())
    }

    public var body: some View {
        List {
            if let tracker = recentEntriesTracker {
                let vaultRecent = tracker.recentEntries.filter { $0.vaultId == viewModel.vault?.id }
                if !vaultRecent.isEmpty && showRecentEntries {
                    Section(isExpanded: $showRecentEntries) {
                        ForEach(vaultRecent.prefix(5)) { recent in
                            Button {
                                if let entry = filteredEntries.first(where: { $0.id == recent.entryId }) {
                                    onSelectEntry(entry)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(recent.title)
                                            .font(.body)
                                        Text(recent.accessedAt, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(recent.title), recently used")
                        }
                    } header: {
                        Text("Recently Used")
                    }
                }
            }

            Section("Entries") {
                ForEach(filteredEntries) { entry in
                Button {
                    onSelectEntry(entry)
                } label: {
                    EntryRowView(entry: entry)
                }
                #if os(iOS)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        entryToDelete = entry
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #else
                .contextMenu {
                    Button(role: .destructive) {
                        entryToDelete = entry
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #endif
                }
            }
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Search entries")
        .onSubmit(of: .search) {
            Task { await viewModel.searchEntries() }
        }
        .onChange(of: viewModel.searchQuery) { _, newValue in
            if newValue.isEmpty {
                Task { await viewModel.refreshEntries() }
            }
        }
        .safeAreaInset(edge: .top) {
            FilterBar(
                typeFilter: $viewModel.typeFilter,
                favoritesOnly: $viewModel.favoritesOnly
            )
        }
        .overlay {
            if viewModel.isLoading && filteredEntries.isEmpty {
                ProgressView("Loading entries…")
            } else if !viewModel.isLoading && filteredEntries.isEmpty && viewModel.vault != nil {
                ContentUnavailableView("No Entries", systemImage: "doc.text.magnifyingglass",
                                       description: Text("No entries match your search or filters."))
            }
        }
        .navigationTitle(viewModel.vault?.name ?? "Vault")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(EntryType.allCases, id: \.self) { type in
                        Button {
                            newEntryType = type
                            showNewEntry = true
                        } label: {
                            Label(newEntryLabel(for: type), systemImage: newEntryIcon(for: type))
                        }
                    }
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                .accessibilityLabel("Add new entry")
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            sortViewModel.selectedSort = option
                        } label: {
                            HStack {
                                Text(sortLabel(for: option))
                                if sortViewModel.selectedSort == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort entries")
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        showRename = true
                    } label: {
                        Label("Rename Vault", systemImage: "pencil")
                    }
                    Button {
                        showChangePassword = true
                    } label: {
                        Label("Change Master Password", systemImage: "lock.rotation")
                    }
                    Button {
                        showExport = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("Vault Actions", systemImage: "ellipsis.circle")
                }
                .accessibilityLabel("Vault actions")
            }
        }
        .sheet(isPresented: $showChangePassword) {
            if let vm = masterPasswordChangeViewModel, let vaultId = viewModel.vault?.id {
                NavigationStack {
                    MasterPasswordChangeView(viewModel: vm, vaultId: vaultId) {
                        showChangePassword = false
                    }
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showChangePassword = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showRename) {
            if let vm = vaultRenameViewModel, let vault = viewModel.vault {
                NavigationStack {
                    VaultRenameView(
                        viewModel: vm,
                        vaultId: vault.id,
                        currentName: vault.name,
                        vaultListViewModel: vaultListViewModel,
                        vaultDetailViewModel: viewModel
                    ) {
                        showRename = false
                    }
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showRename = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showExport) {
            if let vm = exportViewModel, let vaultId = viewModel.vault?.id {
                ExportView(viewModel: vm, vaultId: vaultId)
            }
        }
        .sheet(isPresented: $showNewEntry) {
            NavigationStack {
                EntryFormView(entryType: newEntryType, onSave: { newEntry in
                    Task {
                        await viewModel.createEntry(newEntry)
                        showNewEntry = false
                    }
                }, onCancel: {
                    showNewEntry = false
                })
            }
        }
        .alert("Delete Entry?",
               isPresented: Binding(
                   get: { entryToDelete != nil },
                   set: { if !$0 { entryToDelete = nil } }
               ),
               presenting: entryToDelete
        ) { entry in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteEntry(entry) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { entry in
            Text("Are you sure you want to delete \"\(entry.title)\"? This action cannot be undone.")
        }
    }
}

// MARK: - Entry Row

@available(macOS 14.0, iOS 17.0, *)
struct EntryRowView: View {
    let entry: EntryPropertyRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: entry.type))
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body)
                if let url = entry.url, !url.isEmpty {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if entry.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(entry.type.rawValue)")
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

// MARK: - Sort Label Helper

@available(macOS 14.0, iOS 17.0, *)
extension VaultDetailView {
    func sortLabel(for option: SortOption) -> String {
        switch option {
        case .nameAscending: return "Name (A–Z)"
        case .nameDescending: return "Name (Z–A)"
        case .dateModifiedNewest: return "Modified (Newest)"
        case .dateModifiedOldest: return "Modified (Oldest)"
        case .dateCreatedNewest: return "Created (Newest)"
        case .dateCreatedOldest: return "Created (Oldest)"
        case .entryType: return "Type"
        }
    }

    private func newEntryLabel(for type: EntryType) -> String {
        switch type {
        case .login: return "Login"
        case .secureNote: return "Secure Note"
        case .creditCard: return "Credit Card"
        case .identityDocument: return "Identity Document"
        }
    }

    private func newEntryIcon(for type: EntryType) -> String {
        switch type {
        case .login: return "person.crop.circle"
        case .secureNote: return "note.text"
        case .creditCard: return "creditcard"
        case .identityDocument: return "person.text.rectangle"
        }
    }
}

// MARK: - Filter Bar

@available(macOS 14.0, iOS 17.0, *)
struct FilterBar: View {
    @Binding var typeFilter: EntryType?
    @Binding var favoritesOnly: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: typeFilter == nil) {
                    typeFilter = nil
                }

                ForEach(EntryType.allCases, id: \.self) { type in
                    FilterChip(label: displayName(for: type), isSelected: typeFilter == type) {
                        typeFilter = (typeFilter == type) ? nil : type
                    }
                }

                Divider()
                    .frame(height: 20)

                Toggle(isOn: $favoritesOnly) {
                    Label("Favorites", systemImage: favoritesOnly ? "star.fill" : "star")
                        .font(.subheadline)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(favoritesOnly ? .yellow : .secondary)
                .accessibilityLabel("Filter favorites only")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func displayName(for type: EntryType) -> String {
        switch type {
        case .login: return "Logins"
        case .secureNote: return "Notes"
        case .creditCard: return "Cards"
        case .identityDocument: return "IDs"
        }
    }
}

// MARK: - Filter Chip

@available(macOS 14.0, iOS 17.0, *)
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(label) filter")
    }
}
