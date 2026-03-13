// Property 36: Favorites Aggregation Across Unlocked Vaults
// Validates: Requirements 28.2
//
// `favoriteEntries` contains exactly the entries where `isFavorite == true`
// across all provided vaults, each associated with its correct vault ID.

import XCTest
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class FavoritesAggregationPropertyTests: XCTestCase {

    private func randomEntry(favorite: Bool) -> EntryPropertyRecord {
        EntryPropertyRecord(
            id: UUID().uuidString,
            title: "Entry-\(Int.random(in: 0...9999))",
            type: EntryType.allCases.randomElement()!,
            tags: [],
            url: nil,
            isFavorite: favorite
        )
    }

    /// Property 36: favoriteEntries contains exactly the isFavorite entries
    /// from all vaults, each tagged with the correct vault ID.
    @MainActor
    func testFavoritesAggregationAcrossVaults() {
        for _ in 0..<100 {
            let vaultCount = Int.random(in: 0...5)
            var vaults: [(vaultId: String, entries: [EntryPropertyRecord])] = []
            var expectedFavorites: [(vaultId: String, entryId: String)] = []

            for _ in 0..<vaultCount {
                let vaultId = UUID().uuidString
                let entryCount = Int.random(in: 0...10)
                var entries: [EntryPropertyRecord] = []
                for _ in 0..<entryCount {
                    let isFav = Bool.random()
                    let entry = randomEntry(favorite: isFav)
                    entries.append(entry)
                    if isFav {
                        expectedFavorites.append((vaultId: vaultId, entryId: entry.id))
                    }
                }
                vaults.append((vaultId: vaultId, entries: entries))
            }

            let vm = FavoritesViewModel()
            vm.loadFavorites(from: vaults)

            // Count must match
            XCTAssertEqual(vm.favoriteEntries.count, expectedFavorites.count,
                           "Expected \(expectedFavorites.count) favorites, got \(vm.favoriteEntries.count)")

            // Every returned entry must be a favorite
            for fav in vm.favoriteEntries {
                XCTAssertTrue(fav.entry.isFavorite,
                              "Entry \(fav.entry.id) in favorites but isFavorite is false")
            }

            // Every expected favorite must be present with correct vault ID
            for expected in expectedFavorites {
                let found = vm.favoriteEntries.contains { $0.vaultId == expected.vaultId && $0.entry.id == expected.entryId }
                XCTAssertTrue(found,
                              "Expected favorite \(expected.entryId) in vault \(expected.vaultId) not found")
            }
        }
    }

    /// Empty vaults produce empty favorites.
    @MainActor
    func testEmptyVaultsProduceEmptyFavorites() {
        let vm = FavoritesViewModel()
        vm.loadFavorites(from: [])
        XCTAssertTrue(vm.favoriteEntries.isEmpty)
    }

    /// Vaults with no favorites produce empty favorites.
    @MainActor
    func testNoFavoritesProducesEmpty() {
        let vm = FavoritesViewModel()
        let entries = (0..<5).map { _ in randomEntry(favorite: false) }
        vm.loadFavorites(from: [("v1", entries)])
        XCTAssertTrue(vm.favoriteEntries.isEmpty)
    }
}
