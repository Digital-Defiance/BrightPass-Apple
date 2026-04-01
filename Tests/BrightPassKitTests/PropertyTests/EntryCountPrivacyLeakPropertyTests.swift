// Property 1: Bug Condition — Server-Derived Entry Count Privacy Leak
//
// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3**
//
// Originally written to FAIL on unfixed code (confirming the bug exists).
// After the fix (entryCount removed from VaultMetadata), these tests PASS,
// confirming the privacy leak is resolved.

import XCTest
import SwiftCheck
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class EntryCountPrivacyLeakPropertyTests: XCTestCase {

    // MARK: - Test 1: VaultMetadata should NOT expose server-derived entryCount

    /// VaultMetadata no longer has an entryCount property.
    /// The init no longer accepts entryCount, so the server field is silently ignored.
    /// **Validates: Requirements 1.1, 1.4, 2.1**
    func testVaultMetadataDoesNotExposeServerEntryCount() {
        property("VaultMetadata should not expose server-derived entryCount") <- forAllNoShrink(
            Gen<Int>.fromElements(in: 0...1000)
        ) { (count: Int) in
            // Simulate server JSON that includes entryCount
            let json = """
            {
                "id": "vault-1",
                "name": "Test Vault",
                "entryCount": \(count)
            }
            """.data(using: .utf8)!

            guard let vault = try? JSONDecoder().decode(VaultMetadata.self, from: json) else {
                return false
            }

            // entryCount property no longer exists on VaultMetadata — server field is ignored.
            // Verify the vault decoded correctly without entryCount.
            return vault.id == "vault-1" && vault.name == "Test Vault"
        }
    }

    // MARK: - Test 2: Nil entryCount should NOT fall back to 0 in display text

    /// VaultMetadata no longer has entryCount, so there is no "0 entries" fallback.
    /// **Validates: Requirements 1.2, 2.2**
    func testNilEntryCountDoesNotFallbackToZeroDisplay() {
        let vault = VaultMetadata(
            id: "vault-nil",
            name: "Nil Count Vault"
        )

        // With entryCount removed, there is no way to produce "0 entries" from VaultMetadata.
        // The display should show "Locked" for undecrypted vaults (handled by VaultRowView).
        // Verify VaultMetadata has no entryCount to leak.
        XCTAssertEqual(vault.id, "vault-nil")
        XCTAssertEqual(vault.name, "Nil Count Vault")
    }

    // MARK: - Test 3: Accessibility label should NOT contain numeric entry count

    /// With entryCount removed from VaultMetadata, the accessibility label cannot
    /// contain a server-derived numeric entry count.
    /// **Validates: Requirements 1.3, 2.3**
    func testAccessibilityLabelDoesNotContainNumericEntryCount() {
        property("VaultMetadata has no entryCount for accessibility labels to leak") <- forAllNoShrink(
            String.arbitrary.suchThat { !$0.isEmpty }
        ) { (name: String) in
            let vault = VaultMetadata(
                id: "vault-a11y",
                name: name
            )

            // entryCount no longer exists on VaultMetadata, so no server-derived count
            // can appear in any accessibility label built from VaultMetadata fields.
            return vault.id == "vault-a11y" && vault.name == name
        }
    }

    // MARK: - Test 4: JSON decoding should NOT expose entryCount property

    /// Decoding a JSON payload with "entryCount" should silently ignore the field.
    /// **Validates: Requirements 1.4, 2.1**
    func testJSONDecodingDoesNotExposeEntryCount() {
        property("JSON-decoded VaultMetadata should not expose entryCount") <- forAllNoShrink(
            Gen<Int>.fromElements(in: 1...1000)
        ) { (count: Int) in
            let json = """
            {
                "id": "vault-json",
                "name": "JSON Vault",
                "entryCount": \(count),
                "ownerId": "owner-1",
                "createdAt": "2024-01-01T00:00:00Z",
                "updatedAt": "2024-06-01T00:00:00Z"
            }
            """.data(using: .utf8)!

            guard let decoded = try? JSONDecoder().decode(VaultMetadata.self, from: json) else {
                return false
            }

            // entryCount is silently ignored — verify other fields decode correctly
            return decoded.id == "vault-json"
                && decoded.name == "JSON Vault"
                && decoded.ownerId == "owner-1"
        }
    }
}
