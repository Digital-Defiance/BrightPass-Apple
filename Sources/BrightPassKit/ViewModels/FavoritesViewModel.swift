import Foundation

/// A favorite entry paired with its vault ID for navigation context.
public struct FavoriteEntry: Equatable, Sendable {
    public let vaultId: String
    public let entry: EntryPropertyRecord

    public init(vaultId: String, entry: EntryPropertyRecord) {
        self.vaultId = vaultId
        self.entry = entry
    }
}

/// Aggregates favorited entries across all unlocked vaults.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class FavoritesViewModel {

    public var favoriteEntries: [FavoriteEntry] = []
    public var isLoading: Bool = false
    public var error: AppError?

    public init() {}

    /// Filters entries with `isFavorite == true` from all provided vaults,
    /// tagging each with its vault ID for navigation context.
    public func loadFavorites(from vaults: [(vaultId: String, entries: [EntryPropertyRecord])]) {
        isLoading = true
        error = nil
        favoriteEntries = vaults.flatMap { vault in
            vault.entries
                .filter(\.isFavorite)
                .map { FavoriteEntry(vaultId: vault.vaultId, entry: $0) }
        }
        isLoading = false
    }
}
