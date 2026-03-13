import SwiftUI

/// Displays aggregated favorite entries across all unlocked vaults.
/// iOS: intended as a tab bar item. macOS: sidebar section below vault list.
@available(macOS 14.0, iOS 17.0, *)
public struct FavoritesView: View {
    @Bindable var viewModel: FavoritesViewModel
    let onSelectEntry: (FavoriteEntry) -> Void

    public init(viewModel: FavoritesViewModel,
                onSelectEntry: @escaping (FavoriteEntry) -> Void) {
        self.viewModel = viewModel
        self.onSelectEntry = onSelectEntry
    }

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading favorites…")
            } else if viewModel.favoriteEntries.isEmpty {
                ContentUnavailableView("No Favorites",
                                       systemImage: "star",
                                       description: Text("Mark entries as favorites to see them here."))
            } else {
                List(viewModel.favoriteEntries, id: \.entry.id) { fav in
                    Button {
                        onSelectEntry(fav)
                    } label: {
                        HStack {
                            Image(systemName: iconName(for: fav.entry.type))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fav.entry.title)
                                    .font(.body)
                                if let url = fav.entry.url {
                                    Text(url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(fav.entry.title), favorite")
                }
            }
        }
        .navigationTitle("Favorites")
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
