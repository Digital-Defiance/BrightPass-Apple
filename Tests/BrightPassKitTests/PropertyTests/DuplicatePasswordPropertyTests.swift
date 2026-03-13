// Property 41: Duplicate Password Detection with Accurate Count
// Validates: Requirements 31.1, 31.3
//
// For any vault containing login entries, and any entry E within that vault,
// DuplicatePasswordDetector returns isDuplicate = true iff at least one other
// login entry has the same password as E, and duplicateCount equals the exact
// number of other entries sharing that password.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Generators

/// A small pool of passwords so that duplicates occur naturally.
private let passwordPool: Gen<String> = Gen<String>.fromElements(of: [
    "alpha", "bravo", "charlie", "delta", "echo"
])

/// Generator for a LoginFields value using the password pool.
private let arbitraryLoginFields: Gen<LoginFields> = Gen.compose { c in
    LoginFields(
        siteURL: "https://example.com",
        username: "user-\(UUID().uuidString.prefix(6))",
        password: c.generate(using: passwordPool),
        totpSecret: nil
    )
}

/// Generator for non-login EntryFields (these should be ignored by the detector).
private let arbitraryNonLoginFields: Gen<EntryFields> = Gen<Int>.fromElements(of: [0, 1, 2]).map { kind in
    switch kind {
    case 0:
        return .secureNote(SecureNoteFields(content: "note"))
    case 1:
        return .creditCard(CreditCardFields(
            cardholderName: "Name", cardNumber: "4111111111111111",
            expirationDate: "12/30", cvv: "123"
        ))
    default:
        return .identityDocument(IdentityDocumentFields(
            name: "Name", email: "a@b.com", phone: "555-0100",
            address: "123 St", customFields: [:]
        ))
    }
}

private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

/// Build a VaultEntry from given fields.
private func makeEntry(fields: EntryFields) -> VaultEntry {
    let type: EntryType
    switch fields {
    case .login: type = .login
    case .secureNote: type = .secureNote
    case .creditCard: type = .creditCard
    case .identityDocument: type = .identityDocument
    }
    return VaultEntry(
        id: UUID().uuidString,
        type: type,
        title: "Entry",
        fields: fields,
        tags: [],
        isFavorite: false,
        createdAt: fixedDate,
        updatedAt: fixedDate
    )
}

/// Generator for a mixed list of entries (2–20) containing at least one login entry.
/// Uses the small password pool so duplicates are likely.
private let arbitraryEntryList: Gen<[VaultEntry]> = Gen.compose { c in
    // Generate 1–10 login entries
    let loginCount = abs(c.generate(using: Int.arbitrary)) % 10 + 1
    var entries: [VaultEntry] = (0..<loginCount).map { _ in
        let loginFields = c.generate(using: arbitraryLoginFields)
        return makeEntry(fields: .login(loginFields))
    }
    // Generate 0–5 non-login entries
    let nonLoginCount = abs(c.generate(using: Int.arbitrary)) % 6
    for _ in 0..<nonLoginCount {
        let fields = c.generate(using: arbitraryNonLoginFields)
        entries.append(makeEntry(fields: fields))
    }
    return entries.shuffled()
}

/// Generator for a list of login entries that all have unique passwords (no duplicates).
private let uniquePasswordEntryList: Gen<[VaultEntry]> = Gen.compose { c in
    let count = abs(c.generate(using: Int.arbitrary)) % 8 + 1
    return (0..<count).map { i in
        let fields = LoginFields(
            siteURL: "https://site\(i).com",
            username: "user\(i)",
            password: "unique-password-\(UUID().uuidString)",
            totpSecret: nil
        )
        return makeEntry(fields: .login(fields))
    }
}

// MARK: - Property Tests

/// **Validates: Requirements 31.1, 31.3**
@available(macOS 14.0, iOS 17.0, *)
final class DuplicatePasswordPropertyTests: XCTestCase {

    /// **Property 41: Duplicate Password Detection with Accurate Count**
    ///
    /// For any list of vault entries and any login entry E in that list,
    /// `isDuplicate` is `true` iff at least one OTHER login entry has the
    /// same password, and `duplicateCount` equals the exact count of those
    /// other entries.
    ///
    /// **Validates: Requirements 31.1, 31.3**
    func testDuplicatePasswordDetectionWithAccurateCount() {
        property("isDuplicate and duplicateCount match manual count of other login entries with same password") <- forAllNoShrink(arbitraryEntryList) {
            (allEntries: [VaultEntry]) in

            // Pick a random login entry as the target
            let loginEntries = allEntries.filter {
                if case .login = $0.fields { return true }
                return false
            }
            guard let target = loginEntries.randomElement() else { return true }

            // Extract the target's password
            guard case .login(let targetLogin) = target.fields else { return true }
            let targetPassword = targetLogin.password

            // Call the detector
            let result = DuplicatePasswordDetector.detect(
                entryId: target.id,
                password: targetPassword,
                allEntries: allEntries
            )

            // Manually compute expected duplicates: other login entries with same password
            let expectedDuplicates = allEntries.filter { entry in
                guard entry.id != target.id else { return false }
                guard case .login(let login) = entry.fields else { return false }
                return login.password == targetPassword
            }

            let isDuplicateCorrect = result.isDuplicate == !expectedDuplicates.isEmpty
            let countCorrect = result.duplicateCount == expectedDuplicates.count
            let idsCorrect = Set(result.duplicateEntryIds) == Set(expectedDuplicates.map(\.id))

            return isDuplicateCorrect && countCorrect && idsCorrect
        }
    }

    /// Verify that when no other entry shares the password, isDuplicate is false
    /// and duplicateCount is 0.
    ///
    /// **Validates: Requirements 31.1, 31.3**
    func testNoDuplicatesReturnsZero() {
        property("Unique passwords produce isDuplicate=false and duplicateCount=0") <- forAllNoShrink(uniquePasswordEntryList) {
            (entries: [VaultEntry]) in

            guard let target = entries.first else { return true }
            guard case .login(let login) = target.fields else { return true }

            let result = DuplicatePasswordDetector.detect(
                entryId: target.id,
                password: login.password,
                allEntries: entries
            )

            return result.isDuplicate == false
                && result.duplicateCount == 0
                && result.duplicateEntryIds.isEmpty
        }
    }
}
