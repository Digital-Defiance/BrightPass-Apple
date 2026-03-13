// Property 20: Auto-Lock Timeout Range Validation
// Validates: Requirements 12.3
//
// For any integer value assigned to `AutoLockManager.timeoutMinutes`,
// the stored value shall be clamped to the range [1, 60].

import XCTest
@testable import BrightPassKit

/// **Validates: Requirements 12.3**
@available(macOS 14.0, iOS 17.0, *)
final class AutoLockTimeoutPropertyTests: XCTestCase {

    /// **Property 20: Auto-Lock Timeout Range Validation**
    /// For any random integer assigned to `timeoutMinutes`, the resulting
    /// value is always clamped to [1, 60].
    ///
    /// Uses manual random generation instead of SwiftCheck to avoid
    /// deadlocks with @MainActor isolation and semaphore-based bridges.
    @MainActor
    func testTimeoutMinutesClampedToValidRange() {
        let manager = AutoLockManager()

        // Test a wide spread of random integers including negatives,
        // zero, boundary values, and large values.
        let edgeCases = [Int.min, -1_000_000, -1, 0, 1, 2, 30, 59, 60, 61, 1_000_000, Int.max]
        let randomCases = (0..<200).map { _ in Int.random(in: Int.min...Int.max) }

        for value in edgeCases + randomCases {
            manager.timeoutMinutes = value
            XCTAssertGreaterThanOrEqual(
                manager.timeoutMinutes, 1,
                "timeoutMinutes should be >= 1 after assigning \(value), got \(manager.timeoutMinutes)"
            )
            XCTAssertLessThanOrEqual(
                manager.timeoutMinutes, 60,
                "timeoutMinutes should be <= 60 after assigning \(value), got \(manager.timeoutMinutes)"
            )
        }
    }
}
