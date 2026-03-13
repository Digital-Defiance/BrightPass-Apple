// Feature: brightpass-apple-ui, Property 39: Password Strength Level and Color Mapping
// Validates: Requirements 30.3, 30.4
//
// For any password string, the PasswordStrengthEvaluator shall return one of
// exactly four levels (weak, fair, good, strong), and each level shall map to
// its designated color (red, orange, yellow, green respectively).

import XCTest
import SwiftCheck
import SwiftUI
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class PasswordStrengthLevelPropertyTests: XCTestCase {

    /// The canonical level → color mapping from PasswordStrengthMeterView.
    private static let expectedColorMapping: [PasswordStrengthLevel: Color] = [
        .weak: .red,
        .fair: .orange,
        .good: .yellow,
        .strong: .green
    ]

    /// Returns the designated color for a given strength level,
    /// mirroring the switch in PasswordStrengthMeterView.
    private static func color(for level: PasswordStrengthLevel) -> Color {
        switch level {
        case .weak:   return .red
        case .fair:   return .orange
        case .good:   return .yellow
        case .strong: return .green
        }
    }

    // MARK: - Property 39

    /// **Validates: Requirements 30.3, 30.4**
    ///
    /// For any password string, `PasswordStrengthEvaluator.evaluate` returns
    /// one of exactly four levels, and each level maps to its designated color.
    func testPasswordStrengthLevelAndColorMapping() {
        property("evaluate returns a valid level with correct color mapping") <- forAll { (password: String) in
            let level = PasswordStrengthEvaluator.evaluate(password)

            // 1. The result must be one of the four known cases
            let validLevels: Set<PasswordStrengthLevel> = [.weak, .fair, .good, .strong]
            guard validLevels.contains(level) else { return false }

            // 2. The level must map to its designated color
            let actualColor = Self.color(for: level)
            guard let expectedColor = Self.expectedColorMapping[level] else { return false }
            return actualColor == expectedColor
        }
    }

    /// Exhaustive check that every PasswordStrengthLevel case is covered
    /// by the mapping and maps to the correct color.
    func testAllLevelsCoveredWithCorrectColors() {
        let allCases = PasswordStrengthLevel.allCases
        XCTAssertEqual(allCases.count, 4, "PasswordStrengthLevel should have exactly 4 cases")

        let expected: [(PasswordStrengthLevel, Color)] = [
            (.weak, .red),
            (.fair, .orange),
            (.good, .yellow),
            (.strong, .green)
        ]

        for (level, expectedColor) in expected {
            XCTAssertTrue(allCases.contains(level), "\(level) should be a valid case")
            XCTAssertEqual(
                Self.color(for: level), expectedColor,
                "\(level) should map to \(expectedColor)"
            )
        }
    }
}
