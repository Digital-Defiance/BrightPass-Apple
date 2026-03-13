// Property 25: Clipboard Sensitive Copy Sets Expiration
// Validates: Requirements 16.1
//
// For any non-empty string copied via `ClipboardManager.copySensitive(_:)`,
// the manager SHALL record `localOnly = true` and an expiration date
// approximately 30 seconds in the future.

import XCTest
@testable import BrightPassKit

/// **Validates: Requirements 16.1**
@available(macOS 14.0, iOS 17.0, *)
final class ClipboardExpirationPropertyTests: XCTestCase {

    /// **Property 25: Clipboard Sensitive Copy Sets Expiration**
    /// For any random non-empty string, calling `copySensitive` sets
    /// `lastCopyLocalOnly` to true and `lastCopyExpirationDate` to ~30s from now.
    ///
    /// Uses manual random generation to avoid SwiftCheck/MainActor deadlocks.
    @MainActor
    func testCopySensitiveSetsLocalOnlyAndExpiration() {
        let manager = ClipboardManager()

        // Generate a variety of random strings including edge cases
        let edgeCases = ["a", "password123", "🔑🔒", String(repeating: "x", count: 1000), " "]
        let randomCases: [String] = (0..<200).map { _ in
            let length = Int.random(in: 1...100)
            return String((0..<length).map { _ in
                Character(UnicodeScalar(Int.random(in: 32...126))!)
            })
        }

        let tolerance: TimeInterval = 2.0 // allow 2s tolerance for test execution time

        for value in edgeCases + randomCases {
            let before = Date()
            manager.copySensitive(value)
            let after = Date()

            // Property: localOnly must be true
            XCTAssertTrue(
                manager.lastCopyLocalOnly,
                "lastCopyLocalOnly should be true after copySensitive(\"\(value.prefix(20))...\")"
            )

            // Property: lastCopyDate must be set and within the test window
            XCTAssertNotNil(
                manager.lastCopyDate,
                "lastCopyDate should be non-nil after copySensitive"
            )
            if let copyDate = manager.lastCopyDate {
                XCTAssertGreaterThanOrEqual(copyDate, before)
                XCTAssertLessThanOrEqual(copyDate, after)
            }

            // Property: expirationDate must be ~30 seconds from the copy date
            XCTAssertNotNil(
                manager.lastCopyExpirationDate,
                "lastCopyExpirationDate should be non-nil after copySensitive"
            )
            if let expirationDate = manager.lastCopyExpirationDate,
               let copyDate = manager.lastCopyDate {
                let interval = expirationDate.timeIntervalSince(copyDate)
                XCTAssertEqual(
                    interval,
                    ClipboardManager.expirationInterval,
                    accuracy: tolerance,
                    "Expiration should be ~\(ClipboardManager.expirationInterval)s from copy date, got \(interval)s"
                )
            }
        }
    }

    /// Verify that the static expiration interval is exactly 30 seconds.
    @MainActor
    func testExpirationIntervalIs30Seconds() {
        XCTAssertEqual(ClipboardManager.expirationInterval, 30.0)
    }
}
