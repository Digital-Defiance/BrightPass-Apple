// Feature: brightpass-apple-ui, Property 38: Vault Lock Clears Recent Entries for That Vault
// Validates: Requirements 29.4
//
// For any RecentEntriesTracker containing entries from multiple vaults,
// after calling clearEntriesForVault(_:) with a specific vault ID, no
// entries with that vault ID shall remain in recentEntries, and entries
// from other vaults shall be unaffected.

import XCTest
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class VaultLockClearsRecentPropertyTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let suite = "test.vaultlock.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Property 38: After clearEntriesForVault(_:), no entries with that
    /// vault ID remain, and entries from other vaults are unaffected.
    @MainActor
    func testVaultLockClearsRecentEntriesForThatVault() {
        for _ in 0..<200 {
            let defaults = freshDefaults()
            let tracker = RecentEntriesTracker(defaults: defaults)

            // Generate 2-3 random vault IDs
            let vaultCount = Int.random(in: 2...3)
            let vaultIds = (0..<vaultCount).map { "vault-\($0)-\(UUID().uuidString)" }

            // Generate random entries across vaults (1-4 entries per vault)
            var entriesByVault: [String: [String]] = [:]
            for vaultId in vaultIds {
                let entryCount = Int.random(in: 1...4)
                var entryIds: [String] = []
                for i in 0..<entryCount {
                    let entryId = "entry-\(i)-\(UUID().uuidString)"
                    entryIds.append(entryId)
                    tracker.recordAccess(
                        entryId: entryId,
                        vaultId: vaultId,
                        title: "Title \(i)"
                    )
                }
                entriesByVault[vaultId] = entryIds
            }

            // Pick one vault ID to clear
            let clearedVaultId = vaultIds.randomElement()!
            let otherVaultIds = vaultIds.filter { $0 != clearedVaultId }

            // Snapshot entries from other vaults before clearing
            let otherEntriesBefore = tracker.recentEntries.filter { otherVaultIds.contains($0.vaultId) }
            let otherEntryIdsBefore = Set(otherEntriesBefore.map(\.entryId))
            let otherCountBefore = otherEntriesBefore.count

            // Clear entries for the selected vault
            tracker.clearEntriesForVault(clearedVaultId)

            // Assert: no entries with the cleared vault ID remain
            let remainingCleared = tracker.recentEntries.filter { $0.vaultId == clearedVaultId }
            XCTAssertEqual(
                remainingCleared.count, 0,
                "Expected no entries for vault \(clearedVaultId) after clearEntriesForVault, but found \(remainingCleared.count)"
            )

            // Assert: entries from other vaults are unaffected (same count)
            let otherEntriesAfter = tracker.recentEntries.filter { otherVaultIds.contains($0.vaultId) }
            XCTAssertEqual(
                otherEntriesAfter.count, otherCountBefore,
                "Other vault entries count changed: was \(otherCountBefore), now \(otherEntriesAfter.count)"
            )

            // Assert: entries from other vaults are unaffected (same entry IDs)
            let otherEntryIdsAfter = Set(otherEntriesAfter.map(\.entryId))
            XCTAssertEqual(
                otherEntryIdsAfter, otherEntryIdsBefore,
                "Other vault entry IDs changed after clearing vault \(clearedVaultId)"
            )
        }
    }
}
