// Unit tests for RecentEntriesTracker
// Validates: Requirements 29.1, 29.2, 29.4

import XCTest
@testable import BrightPassKit

private func freshDefaults() -> UserDefaults {
    let suite = "test.recent.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@available(macOS 14.0, iOS 17.0, *)
final class RecentEntriesTrackerTests: XCTestCase {

    /// Fresh tracker starts with an empty list.
    @MainActor
    func testInitiallyEmpty() {
        let tracker = RecentEntriesTracker(defaults: freshDefaults())
        XCTAssertTrue(tracker.recentEntries.isEmpty)
    }

    /// recordAccess adds an entry to the front of the list.
    @MainActor
    func testRecordAccessPrependsEntry() {
        let tracker = RecentEntriesTracker(defaults: freshDefaults())
        tracker.recordAccess(entryId: "e1", vaultId: "v1", title: "Gmail")
        XCTAssertEqual(tracker.recentEntries.count, 1)
        XCTAssertEqual(tracker.recentEntries[0].entryId, "e1")
        XCTAssertEqual(tracker.recentEntries[0].title, "Gmail")

        tracker.recordAccess(entryId: "e2", vaultId: "v1", title: "GitHub")
        XCTAssertEqual(tracker.recentEntries.count, 2)
        XCTAssertEqual(tracker.recentEntries[0].entryId, "e2")
        XCTAssertEqual(tracker.recentEntries[1].entryId, "e1")
    }

    /// Duplicate entryId is moved to front, not duplicated.
    @MainActor
    func testDuplicateAccessMovesToFront() {
        let tracker = RecentEntriesTracker(defaults: freshDefaults())
        tracker.recordAccess(entryId: "e1", vaultId: "v1", title: "Gmail")
        tracker.recordAccess(entryId: "e2", vaultId: "v1", title: "GitHub")
        tracker.recordAccess(entryId: "e1", vaultId: "v1", title: "Gmail")

        XCTAssertEqual(tracker.recentEntries.count, 2)
        XCTAssertEqual(tracker.recentEntries[0].entryId, "e1")
        XCTAssertEqual(tracker.recentEntries[1].entryId, "e2")
    }

    /// List is capped at maxCount (10).
    @MainActor
    func testMaxCountTruncation() {
        let tracker = RecentEntriesTracker(defaults: freshDefaults())
        for i in 0..<15 {
            tracker.recordAccess(entryId: "e\(i)", vaultId: "v1", title: "Entry \(i)")
        }
        XCTAssertEqual(tracker.recentEntries.count, 10)
        // Most recent should be first
        XCTAssertEqual(tracker.recentEntries[0].entryId, "e14")
        XCTAssertEqual(tracker.recentEntries[9].entryId, "e5")
    }

    /// clearEntriesForVault removes only entries for that vault.
    @MainActor
    func testClearEntriesForVault() {
        let tracker = RecentEntriesTracker(defaults: freshDefaults())
        tracker.recordAccess(entryId: "e1", vaultId: "v1", title: "Gmail")
        tracker.recordAccess(entryId: "e2", vaultId: "v2", title: "GitHub")
        tracker.recordAccess(entryId: "e3", vaultId: "v1", title: "Slack")

        tracker.clearEntriesForVault("v1")

        XCTAssertEqual(tracker.recentEntries.count, 1)
        XCTAssertEqual(tracker.recentEntries[0].entryId, "e2")
        XCTAssertEqual(tracker.recentEntries[0].vaultId, "v2")
    }

    /// clearAll empties the list.
    @MainActor
    func testClearAll() {
        let tracker = RecentEntriesTracker(defaults: freshDefaults())
        tracker.recordAccess(entryId: "e1", vaultId: "v1", title: "Gmail")
        tracker.recordAccess(entryId: "e2", vaultId: "v2", title: "GitHub")

        tracker.clearAll()
        XCTAssertTrue(tracker.recentEntries.isEmpty)
    }

    /// Data persists across instances via UserDefaults.
    @MainActor
    func testPersistenceAcrossInstances() {
        let defaults = freshDefaults()
        let tracker1 = RecentEntriesTracker(defaults: defaults)
        tracker1.recordAccess(entryId: "e1", vaultId: "v1", title: "Gmail")
        tracker1.recordAccess(entryId: "e2", vaultId: "v1", title: "GitHub")

        let tracker2 = RecentEntriesTracker(defaults: defaults)
        XCTAssertEqual(tracker2.recentEntries.count, 2)
        XCTAssertEqual(tracker2.recentEntries[0].entryId, "e2")
        XCTAssertEqual(tracker2.recentEntries[1].entryId, "e1")
    }

    /// clearAll persists the empty state.
    @MainActor
    func testClearAllPersists() {
        let defaults = freshDefaults()
        let tracker1 = RecentEntriesTracker(defaults: defaults)
        tracker1.recordAccess(entryId: "e1", vaultId: "v1", title: "Gmail")
        tracker1.clearAll()

        let tracker2 = RecentEntriesTracker(defaults: defaults)
        XCTAssertTrue(tracker2.recentEntries.isEmpty)
    }
}
