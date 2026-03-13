import Foundation

/// Manages entry sort state for the vault detail view.
/// Session-scoped persistence (in-memory only).
@available(macOS 14.0, iOS 17.0, *)
@Observable
public class EntrySortViewModel {

    public var selectedSort: SortOption = .nameAscending

    public init() {}

    /// Sorts the given entries according to `selectedSort`.
    public func sortEntries(_ entries: [EntryPropertyRecord]) -> [EntryPropertyRecord] {
        entries.sorted { a, b in
            switch selectedSort {
            case .nameAscending:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .nameDescending:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedDescending
            case .dateModifiedNewest:
                return (a.updatedAt ?? .distantPast) > (b.updatedAt ?? .distantPast)
            case .dateModifiedOldest:
                return (a.updatedAt ?? .distantFuture) < (b.updatedAt ?? .distantFuture)
            case .dateCreatedNewest:
                return (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
            case .dateCreatedOldest:
                return (a.createdAt ?? .distantFuture) < (b.createdAt ?? .distantFuture)
            case .entryType:
                return a.type.rawValue < b.type.rawValue
            }
        }
    }
}
