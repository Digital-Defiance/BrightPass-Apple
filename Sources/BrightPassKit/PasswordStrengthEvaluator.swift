import Foundation

/// Evaluates password strength based on length, character variety, and absence of common patterns.
///
/// **Validates: Requirements 30.1, 30.2, 30.3, 30.4, 30.5**
public struct PasswordStrengthEvaluator {

    private static let commonPatterns: Set<String> = [
        "password", "123456", "qwerty", "abc123",
        "letmein", "admin", "welcome", "monkey", "master"
    ]

    /// Scores a password and returns one of four strength levels.
    ///
    /// Scoring rules (monotonic — adding characters from new classes never decreases strength):
    /// - Empty or fewer than 8 characters → `.weak`
    /// - Exact match of a common pattern (case-insensitive) → `.weak`
    /// - Count character classes: uppercase, lowercase, digits, special
    /// - length ≥ 16 AND 4 classes → `.strong`
    /// - length ≥ 12 AND ≥ 3 classes → `.good`
    /// - length ≥ 8 AND ≥ 2 classes → `.fair`
    /// - Otherwise → `.weak`
    public static func evaluate(_ password: String) -> PasswordStrengthLevel {
        let length = password.count

        guard length >= 8 else {
            return .weak
        }

        if commonPatterns.contains(password.lowercased()) {
            return .weak
        }

        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLower = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil

        let classCount = [hasUpper, hasLower, hasDigit, hasSpecial].filter { $0 }.count

        if length >= 16 && classCount == 4 {
            return .strong
        } else if length >= 12 && classCount >= 3 {
            return .good
        } else if length >= 8 && classCount >= 2 {
            return .fair
        } else {
            return .weak
        }
    }
}
