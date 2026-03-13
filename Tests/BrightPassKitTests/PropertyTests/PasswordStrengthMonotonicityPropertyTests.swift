// Feature: brightpass-apple-ui, Property 40: Password Strength Monotonicity
// Validates: Requirements 30.5
//
// For any password string P, appending additional characters from new character
// classes (e.g., adding a digit to an all-lowercase password) shall produce a
// strength level that is greater than or equal to the original strength level.
// Strength is never reduced by increasing length or character variety.

import XCTest
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class PasswordStrengthMonotonicityPropertyTests: XCTestCase {

    // MARK: - Helpers

    /// Maps PasswordStrengthLevel to an integer for comparison.
    private static func ordinal(_ level: PasswordStrengthLevel) -> Int {
        switch level {
        case .weak:   return 0
        case .fair:   return 1
        case .good:   return 2
        case .strong: return 3
        }
    }

    /// Character pools for each class.
    private static let uppercaseChars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let lowercaseChars = Array("abcdefghijklmnopqrstuvwxyz")
    private static let digitChars     = Array("0123456789")
    private static let specialChars   = Array("!@#$%^&*()-_=+")

    /// Generates a random string of the given length from the provided pool.
    private static func randomString(length: Int, from pool: [Character]) -> String {
        String((0..<length).map { _ in pool.randomElement()! })
    }

    /// Determines which character classes are present in a password.
    private static func characterClasses(of password: String) -> (hasUpper: Bool, hasLower: Bool, hasDigit: Bool, hasSpecial: Bool) {
        let hasUpper   = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLower   = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit   = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        return (hasUpper, hasLower, hasDigit, hasSpecial)
    }

    // MARK: - Property 40

    /// **Validates: Requirements 30.5**
    ///
    /// For any random base password (length >= 8), appending characters from a
    /// new character class that was missing — or appending more characters if all
    /// classes are already present — shall never decrease the strength level.
    func testPasswordStrengthMonotonicity() {
        // Build a pool of all printable characters for base password generation
        let allPool = Self.uppercaseChars + Self.lowercaseChars + Self.digitChars + Self.specialChars

        for _ in 0..<200 {
            // 1. Generate a random base password of length 8–24
            let baseLength = Int.random(in: 8...24)
            let basePassword = Self.randomString(length: baseLength, from: allPool)

            // 2. Evaluate original strength
            let originalLevel = PasswordStrengthEvaluator.evaluate(basePassword)

            // 3. Determine which character classes are missing
            let classes = Self.characterClasses(of: basePassword)
            var suffix = ""

            if !classes.hasUpper {
                suffix += String(Self.uppercaseChars.randomElement()!)
            }
            if !classes.hasLower {
                suffix += String(Self.lowercaseChars.randomElement()!)
            }
            if !classes.hasDigit {
                suffix += String(Self.digitChars.randomElement()!)
            }
            if !classes.hasSpecial {
                suffix += String(Self.specialChars.randomElement()!)
            }

            // If all classes are already present, just append more characters
            // (length increase should also not decrease strength)
            if suffix.isEmpty {
                suffix = Self.randomString(length: Int.random(in: 1...4), from: allPool)
            }

            // 4. Evaluate extended password strength
            let extendedPassword = basePassword + suffix
            let extendedLevel = PasswordStrengthEvaluator.evaluate(extendedPassword)

            // 5. Assert monotonicity: extended level >= original level
            XCTAssertGreaterThanOrEqual(
                Self.ordinal(extendedLevel),
                Self.ordinal(originalLevel),
                "Strength decreased from \(originalLevel) to \(extendedLevel) " +
                "when extending '\(basePassword)' (len=\(basePassword.count)) " +
                "with '\(suffix)' → '\(extendedPassword)' (len=\(extendedPassword.count))"
            )
        }
    }
}
