import Foundation

/// Tracks the most recently accessed vault entries, persisted locally via UserDefaults.
/// Used to display a "Recently Used" section for quick re-access.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class RecentEntriesTracker {

    private static let defaultsKey = "recent-entries"
    private let defaults: UserDefaults

    public var recentEntries: [RecentEntryReference] = []
    public let maxCount = 10

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.recentEntries = Self.load(from: defaults)
    }

    /// Records an entry access. Removes any existing reference to the same entry,
    /// prepends the new reference, and truncates to `maxCount`.
    public func recordAccess(entryId: String, vaultId: String, title: String) {
        recentEntries.removeAll { $0.entryId == entryId }
        let entry = RecentEntryReference(
            id: UUID().uuidString,
            entryId: entryId,
            vaultId: vaultId,
            title: title,
            accessedAt: Date()
        )
        recentEntries.insert(entry, at: 0)
        if recentEntries.count > maxCount {
            recentEntries = Array(recentEntries.prefix(maxCount))
        }
        persist()
    }

    /// Removes all entries associated with the given vault ID.
    /// Called when a vault is locked.
    public func clearEntriesForVault(_ vaultId: String) {
        recentEntries.removeAll { $0.vaultId == vaultId }
        persist()
    }

    /// Empties the entire recent entries list.
    public func clearAll() {
        recentEntries = []
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONCoding.encoder.encode(recentEntries) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    private static func load(from defaults: UserDefaults) -> [RecentEntryReference] {
        guard let data = defaults.data(forKey: defaultsKey) else { return [] }
        return (try? JSONCoding.decoder.decode([RecentEntryReference].self, from: data)) ?? []
    }
}
