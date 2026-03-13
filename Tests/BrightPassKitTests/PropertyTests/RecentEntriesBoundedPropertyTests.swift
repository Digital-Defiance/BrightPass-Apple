// Feature: brightpass-apple-ui, Property 37: Recent Entries Bounded List
// Validates: Requirements 29.1
//
// For any sequence of N entry accesses (where N > 10), the
// RecentEntriesTracker's `recentEntries` list shall contain at most 10
// entries, and they shall be the 10 most recently accessed entries in
// reverse chronological order.

import XCTest
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class RecentEntriesBoundedPropertyTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let suite = "test.recent.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Property 37: For any sequence of N > 10 entry accesses,
    /// `recentEntries` contains at most 10 entries in reverse
    /// chronological order, and they are the last 10 recorded.
    @MainActor
    func testRecentEntriesBoundedList() {
        for _ in 0..<200 {
            let defaults = freshDefaults()
            let tracker = RecentEntriesTracker(defaults: defaults)

            // Random N in [11, 30]
            let n = Int.random(in: 11...30)

            // Generate N unique entry IDs and record accesses in order
            var allEntryIds: [String] = []
            for i in 0..<n {
                let entryId = "entry-\(i)-\(UUID().uuidString)"
                allEntryIds.append(entryId)
                tracker.recordAccess(
                    entryId: entryId,
                    vaultId: "vault-1",
                    title: "Title \(i)"
                )
            }

            // 1. Count must be at most 10
            XCTAssertLessThanOrEqual(
                tracker.recentEntries.count, 10,
                "recentEntries should contain at most 10 entries after \(n) accesses, got \(tracker.recentEntries.count)"
            )

            // 2. The entries should be the last 10 that were recorded
            let expectedEntryIds = Array(allEntryIds.suffix(10).reversed())
            let actualEntryIds = tracker.recentEntries.map(\.entryId)
            XCTAssertEqual(
                actualEntryIds, expectedEntryIds,
                "recentEntries should contain the last 10 recorded entries in reverse chronological order"
            )

            // 3. Entries are in reverse chronological order (most recent first)
            let dates = tracker.recentEntries.map(\.accessedAt)
            for j in 0..<(dates.count - 1) {
                XCTAssertGreaterThanOrEqual(
                    dates[j], dates[j + 1],
                    "Entry at index \(j) should have accessedAt >= entry at index \(j + 1)"
                )
            }
        }
    }
}
