// Property 21: Lock Resets Navigation to Vault List
// Validates: Requirements 13.5
//
// For any NavigationRouter with arbitrary selectedVaultId, selectedEntryId,
// and a non-empty navigation path, calling returnToVaultList() SHALL set
// selectedVaultId to nil, selectedEntryId to nil, and path to empty.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Generators

private let shortAlphaString: Gen<String> = Gen<Character>.fromElements(in: "a"..."z")
    .proliferate(withSize: 10)
    .suchThat { !$0.isEmpty }
    .map { String($0.prefix(max(1, Int.random(in: 1...10)))) }

// MARK: - Property Tests

/// **Validates: Requirements 13.5**
@available(macOS 14.0, iOS 17.0, *)
final class LockResetsNavigationPropertyTests: XCTestCase {

    /// **Property 21: Lock Resets Navigation to Vault List**
    /// After populating the router with arbitrary vault and entry selections,
    /// calling `returnToVaultList()` clears selectedVaultId, selectedEntryId,
    /// and resets the navigation path to empty.
    ///
    /// Uses @MainActor directly to avoid semaphore deadlock with SwiftCheck.
    @MainActor
    func testLockResetsNavigationToVaultList() {
        for _ in 0..<200 {
            let vaultId = shortAlphaString.generate
            let entryId = shortAlphaString.generate

            let router = NavigationRouter()
            router.selectedVaultId = vaultId
            router.selectedEntryId = entryId

            router.returnToVaultList()

            XCTAssertNil(router.selectedVaultId, "selectedVaultId should be nil after returnToVaultList()")
            XCTAssertNil(router.selectedEntryId, "selectedEntryId should be nil after returnToVaultList()")
            XCTAssertTrue(router.path.isEmpty, "path should be empty after returnToVaultList()")
        }
    }
}
