// Unit tests for recent entries, password strength, and duplicate detection
// Validates: Requirements 29.1, 29.4, 30.3, 30.5, 31.1, 31.3

import XCTest
@testable import BrightPassKit

// MARK: - Helpers

private func freshDefaults() -> UserDefaults {
    let suite = "test.unit.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

private func makeLoginEntry(id: String = UUID().uuidString,
                            title: String = "Login",
                            password: String = "secret123") -> VaultEntry {
    VaultEntry(
        id: id, type: .login, title: title,
        fields: .login(LoginFields(siteURL: "https://example.com",
                                   username: "user", password: password,
                                   totpSecret: nil)),
        tags: [], isFavorite: false,
        createdAt: Date(), updatedAt: Date()
    )
}

private func makeSecureNoteEntry(id: String = UUID().uuidString) -> VaultEntry {
    VaultEntry(
        id: id, type: .secureNote, title: "Note",
        fields: .secureNote(SecureNoteFields(content: "secret")),
        tags: [], isFavorite: false,
        createdAt: Date(), updatedAt: Date()
    )
}

private func makeCreditCardEntry(id: String = UUID().uuidString) -> VaultEntry {
    VaultEntry(
        id: id, type: .creditCard, title: "Card",
        fields: .creditCard(CreditCardFields(cardholderName: "John",
                                             cardNumber: "4111111111111111",
                                             expirationDate: "12/25", cvv: "123")),
        tags: [], isFavorite: false,
        createdAt: Date(), updatedAt: Date()
    )
}

private func makeIdentityEntry(id: String = UUID().uuidString) -> VaultEntry {
    VaultEntry(
        id: id, type: .identityDocument, title: "ID",
        fields: .identityDocument(IdentityDocumentFields(
            name: "Jane", email: "jane@example.com",
            phone: "555-0100", address: "123 Main St",
            customFields: [:])),
        tags: [], isFavorite: false,
        createdAt: Date(), updatedAt: Date()
    )
}

// MARK: - Recent Entries Tests

@available(macOS 14.0, iOS 17.0, *)
final class RecentEntriesUnitTests: XCTestCase {

    /// Recording 12 entries keeps only the most recent 10.
    @MainActor
    func testMaxTenCap() {
        let tracker = RecentEntriesTracker(defaults: freshDefaults())
        for i in 0..<12 {
            tracker.recordAccess(entryId: "e\(i)", vaultId: "v1", title: "Entry \(i)")
        }
        XCTAssertEqual(tracker.recentEntries.count, 10)
        // Most recent entry should be at index 0
        XCTAssertEqual(tracker.recentEntries[0].entryId, "e11")
        // Oldest surviving entry should be e2 (e0 and e1 were evicted)
        XCTAssertEqual(tracker.recentEntries[9].entryId, "e2")
    }

    /// Clearing one vault's entries leaves the other vault's entries intact.
    @MainActor
    func testVaultLockClearsOnlyThatVault() {
        let tracker = RecentEntriesTracker(defaults: freshDefaults())
        tracker.recordAccess(entryId: "a1", vaultId: "vaultA", title: "A1")
        tracker.recordAccess(entryId: "a2", vaultId: "vaultA", title: "A2")
        tracker.recordAccess(entryId: "b1", vaultId: "vaultB", title: "B1")
        tracker.recordAccess(entryId: "b2", vaultId: "vaultB", title: "B2")

        tracker.clearEntriesForVault("vaultA")

        XCTAssertEqual(tracker.recentEntries.count, 2)
        XCTAssertTrue(tracker.recentEntries.allSatisfy { $0.vaultId == "vaultB" })
    }

    /// Re-accessing an entry moves it to position 0.
    @MainActor
    func testDuplicateAccessUpdatesPosition() {
        let tracker = RecentEntriesTracker(defaults: freshDefaults())
        tracker.recordAccess(entryId: "first", vaultId: "v1", title: "First")
        tracker.recordAccess(entryId: "second", vaultId: "v1", title: "Second")
        tracker.recordAccess(entryId: "third", vaultId: "v1", title: "Third")

        // "first" is now at index 2; re-access it
        tracker.recordAccess(entryId: "first", vaultId: "v1", title: "First")

        XCTAssertEqual(tracker.recentEntries[0].entryId, "first")
        // No duplicates — total count should still be 3
        XCTAssertEqual(tracker.recentEntries.count, 3)
    }
}

// MARK: - Password Strength Tests

final class PasswordStrengthUnitTests: XCTestCase {

    // MARK: Weak passwords

    func testEmptyStringIsWeak() {
        XCTAssertEqual(PasswordStrengthEvaluator.evaluate(""), .weak)
    }

    func testSevenCharPasswordIsWeak() {
        // 7 chars, even with multiple classes
        XCTAssertEqual(PasswordStrengthEvaluator.evaluate("Abcde1!"), .weak)
    }

    func testCommonPatternPasswordIsWeak() {
        XCTAssertEqual(PasswordStrengthEvaluator.evaluate("password"), .weak)
    }

    // MARK: Fair passwords

    func testEightCharsWithTwoClassesIsFair() {
        // 8 chars, uppercase + lowercase = 2 classes
        XCTAssertEqual(PasswordStrengthEvaluator.evaluate("Abcdefgh"), .fair)
    }

    // MARK: Good passwords

    func testTwelveCharsWithThreeClassesIsGood() {
        // 12 chars, uppercase + lowercase + digit = 3 classes
        XCTAssertEqual(PasswordStrengthEvaluator.evaluate("Abcdefghij1k"), .good)
    }

    // MARK: Strong passwords

    func testSixteenCharsWithFourClassesIsStrong() {
        // 16 chars, uppercase + lowercase + digit + special = 4 classes
        XCTAssertEqual(PasswordStrengthEvaluator.evaluate("Abcdefghij1k!@#$"), .strong)
    }

    // MARK: Common pattern detection

    func testAllCommonPatternsAreWeak() {
        let patterns = [
            "password", "123456", "qwerty", "abc123",
            "letmein", "admin", "welcome", "monkey", "master"
        ]
        for pattern in patterns {
            XCTAssertEqual(PasswordStrengthEvaluator.evaluate(pattern), .weak,
                           "Expected '\(pattern)' to be .weak")
        }
    }
}


// MARK: - Duplicate Password Detection Tests

final class DuplicatePasswordUnitTests: XCTestCase {

    func testNoDuplicatesReturnsFalseAndZero() {
        let entry1 = makeLoginEntry(id: "e1", password: "alpha")
        let entry2 = makeLoginEntry(id: "e2", password: "beta")
        let entry3 = makeLoginEntry(id: "e3", password: "gamma")

        let result = DuplicatePasswordDetector.detect(
            entryId: "e1", password: "alpha", allEntries: [entry1, entry2, entry3])

        XCTAssertFalse(result.isDuplicate)
        XCTAssertEqual(result.duplicateCount, 0)
        XCTAssertTrue(result.duplicateEntryIds.isEmpty)
    }

    func testSingleDuplicateDetection() {
        let entry1 = makeLoginEntry(id: "e1", password: "same")
        let entry2 = makeLoginEntry(id: "e2", password: "same")

        let result = DuplicatePasswordDetector.detect(
            entryId: "e1", password: "same", allEntries: [entry1, entry2])

        XCTAssertTrue(result.isDuplicate)
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.duplicateEntryIds, ["e2"])
    }

    func testMultipleDuplicateDetection() {
        let entry1 = makeLoginEntry(id: "e1", password: "same")
        let entry2 = makeLoginEntry(id: "e2", password: "same")
        let entry3 = makeLoginEntry(id: "e3", password: "same")
        let entry4 = makeLoginEntry(id: "e4", password: "different")

        let result = DuplicatePasswordDetector.detect(
            entryId: "e1", password: "same",
            allEntries: [entry1, entry2, entry3, entry4])

        XCTAssertTrue(result.isDuplicate)
        XCTAssertEqual(result.duplicateCount, 2)
        XCTAssertTrue(result.duplicateEntryIds.contains("e2"))
        XCTAssertTrue(result.duplicateEntryIds.contains("e3"))
        XCTAssertFalse(result.duplicateEntryIds.contains("e4"))
    }

    func testNonLoginEntriesExcludedFromDuplicateDetection() {
        let loginEntry = makeLoginEntry(id: "e1", password: "secret")
        let noteEntry = makeSecureNoteEntry(id: "e2")
        let cardEntry = makeCreditCardEntry(id: "e3")
        let idEntry = makeIdentityEntry(id: "e4")

        let result = DuplicatePasswordDetector.detect(
            entryId: "e1", password: "secret",
            allEntries: [loginEntry, noteEntry, cardEntry, idEntry])

        XCTAssertFalse(result.isDuplicate)
        XCTAssertEqual(result.duplicateCount, 0)
        XCTAssertTrue(result.duplicateEntryIds.isEmpty)
    }
}
