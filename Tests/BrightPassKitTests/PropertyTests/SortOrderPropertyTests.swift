// Property 33: Sort Order Correctness on Filtered Entries
// Validates: Requirements 24.2, 24.4
//
// For any list of entries, any filter (type + favorites), and any sort option,
// the result is both correctly filtered AND correctly sorted.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Generators

private let arbitraryEntryType: Gen<EntryType> = Gen<Int>.fromElements(in: 0...3).map {
    EntryType.allCases[$0]
}

private let shortAlphaString: Gen<String> = Gen<Character>.fromElements(in: "a"..."z")
    .proliferate(withSize: 10)
    .suchThat { !$0.isEmpty }
    .map { String($0.prefix(max(1, Int.random(in: 1...10)))) }

private let arbitraryDate: Gen<Date> = Gen<Int>.fromElements(in: 0...1_000_000).map {
    Date(timeIntervalSince1970: TimeInterval($0))
}

private let arbitraryEntry: Gen<EntryPropertyRecord> = Gen.compose { c in
    EntryPropertyRecord(
        id: UUID().uuidString,
        title: c.generate(using: shortAlphaString),
        type: c.generate(using: arbitraryEntryType),
        tags: [],
        url: nil,
        isFavorite: c.generate(),
        createdAt: c.generate(using: arbitraryDate),
        updatedAt: c.generate(using: arbitraryDate)
    )
}

private let entryList: Gen<[EntryPropertyRecord]> = Gen.compose { c in
    let count = abs(c.generate(using: Int.arbitrary)) % 20
    return (0..<count).map { _ in c.generate(using: arbitraryEntry) }
}

private let arbitrarySortOption: Gen<SortOption> = Gen<Int>.fromElements(in: 0...6).map {
    SortOption.allCases[$0]
}

private let arbitraryTypeFilter: Gen<EntryType?> = Gen.one(of: [
    Gen.pure(nil),
    arbitraryEntryType.map { Optional($0) }
])

// MARK: - Tests

@available(macOS 14.0, iOS 17.0, *)
final class SortOrderPropertyTests: XCTestCase {

    /// Property 33: Sort Order Correctness on Filtered Entries
    /// For any entries, filter, and sort option, the result is correctly filtered AND sorted.
    @MainActor
    func testSortOrderCorrectnessOnFilteredEntries() {
        for _ in 0..<200 {
            let entries = entryList.generate
            let sortOption = arbitrarySortOption.generate
            let typeFilter: EntryType? = arbitraryTypeFilter.generate
            let favoritesOnly: Bool = Bool.arbitrary.generate

            // Apply filter (same logic as VaultDetailViewModel.filterEntries)
            var filtered = entries
            if let tf = typeFilter {
                filtered = filtered.filter { $0.type == tf }
            }
            if favoritesOnly {
                filtered = filtered.filter { $0.isFavorite }
            }

            // Apply sort
            let sortVM = EntrySortViewModel()
            sortVM.selectedSort = sortOption
            let result = sortVM.sortEntries(filtered)

            // Verify filter correctness
            if let tf = typeFilter {
                XCTAssertTrue(result.allSatisfy { $0.type == tf },
                              "Filter by type \(tf) failed for sort \(sortOption)")
            }
            if favoritesOnly {
                XCTAssertTrue(result.allSatisfy { $0.isFavorite },
                              "Favorites filter failed for sort \(sortOption)")
            }

            // Verify sort correctness (pairwise)
            for i in 0..<result.count where i + 1 < result.count {
                let a = result[i]
                let b = result[i + 1]
                switch sortOption {
                case .nameAscending:
                    XCTAssertTrue(a.title.localizedCaseInsensitiveCompare(b.title) != .orderedDescending,
                                  "nameAscending violated: \(a.title) > \(b.title)")
                case .nameDescending:
                    XCTAssertTrue(a.title.localizedCaseInsensitiveCompare(b.title) != .orderedAscending,
                                  "nameDescending violated: \(a.title) < \(b.title)")
                case .dateModifiedNewest:
                    XCTAssertTrue((a.updatedAt ?? .distantPast) >= (b.updatedAt ?? .distantPast))
                case .dateModifiedOldest:
                    XCTAssertTrue((a.updatedAt ?? .distantFuture) <= (b.updatedAt ?? .distantFuture))
                case .dateCreatedNewest:
                    XCTAssertTrue((a.createdAt ?? .distantPast) >= (b.createdAt ?? .distantPast))
                case .dateCreatedOldest:
                    XCTAssertTrue((a.createdAt ?? .distantFuture) <= (b.createdAt ?? .distantFuture))
                case .entryType:
                    XCTAssertTrue(a.type.rawValue <= b.type.rawValue,
                                  "entryType violated: \(a.type.rawValue) > \(b.type.rawValue)")
                }
            }
        }
    }
}
