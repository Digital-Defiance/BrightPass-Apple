// Property 4: Malformed JSON Throws DecodingError
// Validates: Requirements 19.4
//
// For each model type, generate JSON payloads with missing required fields
// and verify DecodingError is thrown rather than silently producing default values.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Helper

/// Encodes a value to JSON, removes the specified key from the resulting dictionary,
/// re-serializes, and attempts to decode — expecting a DecodingError.
private func assertMissingFieldThrowsDecodingError<T: Codable>(
    _ value: T,
    removingKey key: String,
    type: T.Type,
    file: StaticString = #file,
    line: UInt = #line
) -> Bool {
    do {
        let data = try JSONCoding.encoder.encode(value)
        guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        dict.removeValue(forKey: key)
        let mutatedData = try JSONSerialization.data(withJSONObject: dict)
        _ = try JSONCoding.decoder.decode(type, from: mutatedData)
        // If we get here, decoding succeeded when it should have failed
        return false
    } catch is DecodingError {
        return true
    } catch {
        // Some other error — still acceptable as a failure, but we specifically want DecodingError
        return false
    }
}

// MARK: - Property Tests

/// **Validates: Requirements 19.4**
/// Property 4: Malformed JSON Throws DecodingError
/// For each model type, removing a required field from valid JSON causes DecodingError.
final class MalformedJSONPropertyTests: XCTestCase {

    // MARK: - VaultMetadata (required: id, name)

    func testVaultMetadataMissingRequiredFields() {
        let requiredKeys = ["id", "name"]
        for key in requiredKeys {
            property("VaultMetadata missing '\(key)' throws DecodingError") <- forAll { (value: VaultMetadata) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: VaultMetadata.self)
            }
        }
    }

    // MARK: - DecryptedVault (required: id, name, entries)

    func testDecryptedVaultMissingRequiredFields() {
        let requiredKeys = ["id", "name", "entries"]
        for key in requiredKeys {
            property("DecryptedVault missing '\(key)' throws DecodingError") <- forAll { (value: DecryptedVault) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: DecryptedVault.self)
            }
        }
    }

    // MARK: - EntryPropertyRecord (required: title, entryType — uses custom CodingKeys)
    // Note: id defaults to UUID, tags defaults to [], favorite defaults to false,
    // so only title and entryType are truly required.

    func testEntryPropertyRecordMissingRequiredFields() {
        let requiredKeys = ["title", "entryType"]
        for key in requiredKeys {
            property("EntryPropertyRecord missing '\(key)' throws DecodingError") <- forAll { (value: EntryPropertyRecord) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: EntryPropertyRecord.self)
            }
        }
    }

    // MARK: - VaultEntry (required: id, type, title, fields, tags, isFavorite, createdAt, updatedAt)

    func testVaultEntryMissingRequiredFields() {
        let requiredKeys = ["id", "type", "title", "fields", "tags", "isFavorite", "createdAt", "updatedAt"]
        for key in requiredKeys {
            property("VaultEntry missing '\(key)' throws DecodingError") <- forAll { (value: VaultEntry) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: VaultEntry.self)
            }
        }
    }

    // MARK: - GeneratedPassword (required: password)

    func testGeneratedPasswordMissingRequiredFields() {
        property("GeneratedPassword missing 'password' throws DecodingError") <- forAll { (value: GeneratedPassword) in
            return assertMissingFieldThrowsDecodingError(value, removingKey: "password", type: GeneratedPassword.self)
        }
    }

    // MARK: - PasswordOptions (required: length, includeUppercase, includeLowercase, includeDigits, includeSpecial, minUppercase, minDigits, minSpecial)

    func testPasswordOptionsMissingRequiredFields() {
        let requiredKeys = ["length", "includeUppercase", "includeLowercase", "includeDigits", "includeSpecial", "minUppercase", "minDigits", "minSpecial"]
        for key in requiredKeys {
            property("PasswordOptions missing '\(key)' throws DecodingError") <- forAll { (value: PasswordOptions) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: PasswordOptions.self)
            }
        }
    }

    // MARK: - TotpCode (required: code, remainingSeconds, period)

    func testTotpCodeMissingRequiredFields() {
        let requiredKeys = ["code", "remainingSeconds", "period"]
        for key in requiredKeys {
            property("TotpCode missing '\(key)' throws DecodingError") <- forAll { (value: TotpCode) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: TotpCode.self)
            }
        }
    }

    // MARK: - BreachCheckResult (required: breached)

    func testBreachCheckResultMissingRequiredFields() {
        property("BreachCheckResult missing 'breached' throws DecodingError") <- forAll { (value: BreachCheckResult) in
            return assertMissingFieldThrowsDecodingError(value, removingKey: "breached", type: BreachCheckResult.self)
        }
    }

    // MARK: - AutofillPayload (required: entryId, title, username, password, url)

    func testAutofillPayloadMissingRequiredFields() {
        let requiredKeys = ["entryId", "title", "username", "password", "url"]
        for key in requiredKeys {
            property("AutofillPayload missing '\(key)' throws DecodingError") <- forAll { (value: AutofillPayload) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: AutofillPayload.self)
            }
        }
    }

    // MARK: - AuditLogEntry (required: id, action, memberId, timestamp)

    func testAuditLogEntryMissingRequiredFields() {
        let requiredKeys = ["id", "action", "memberId", "timestamp"]
        for key in requiredKeys {
            property("AuditLogEntry missing '\(key)' throws DecodingError") <- forAll { (value: AuditLogEntry) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: AuditLogEntry.self)
            }
        }
    }

    // MARK: - SharedMember (required: id, memberId, permission)

    func testSharedMemberMissingRequiredFields() {
        let requiredKeys = ["id", "memberId", "permission"]
        for key in requiredKeys {
            property("SharedMember missing '\(key)' throws DecodingError") <- forAll { (value: SharedMember) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: SharedMember.self)
            }
        }
    }

    // MARK: - EmergencyAccessConfig (required: totalShares, threshold, trustees)

    func testEmergencyAccessConfigMissingRequiredFields() {
        let requiredKeys = ["totalShares", "threshold", "trustees"]
        for key in requiredKeys {
            property("EmergencyAccessConfig missing '\(key)' throws DecodingError") <- forAll { (value: EmergencyAccessConfig) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: EmergencyAccessConfig.self)
            }
        }
    }

    // MARK: - ImportResult (required: importedCount, errors)

    func testImportResultMissingRequiredFields() {
        let requiredKeys = ["importedCount", "errors"]
        for key in requiredKeys {
            property("ImportResult missing '\(key)' throws DecodingError") <- forAll { (value: ImportResult) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: ImportResult.self)
            }
        }
    }

    // MARK: - AuthToken (required: token, expiresAt)

    func testAuthTokenMissingRequiredFields() {
        let requiredKeys = ["token", "expiresAt"]
        for key in requiredKeys {
            property("AuthToken missing '\(key)' throws DecodingError") <- forAll { (value: AuthToken) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: AuthToken.self)
            }
        }
    }

    // MARK: - APIError (required: status, code, message)

    func testAPIErrorMissingRequiredFields() {
        let requiredKeys = ["status", "code", "message"]
        for key in requiredKeys {
            property("APIError missing '\(key)' throws DecodingError") <- forAll { (value: APIError) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: APIError.self)
            }
        }
    }

    // MARK: - RecentEntryReference (required: id, entryId, vaultId, title, accessedAt)

    func testRecentEntryReferenceMissingRequiredFields() {
        let requiredKeys = ["id", "entryId", "vaultId", "title", "accessedAt"]
        for key in requiredKeys {
            property("RecentEntryReference missing '\(key)' throws DecodingError") <- forAll { (value: RecentEntryReference) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: RecentEntryReference.self)
            }
        }
    }

    // MARK: - LoginFields (required: siteURL, username, password)

    func testLoginFieldsMissingRequiredFields() {
        let requiredKeys = ["siteURL", "username", "password"]
        for key in requiredKeys {
            property("LoginFields missing '\(key)' throws DecodingError") <- forAll { (value: LoginFields) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: LoginFields.self)
            }
        }
    }

    // MARK: - SecureNoteFields (required: content)

    func testSecureNoteFieldsMissingRequiredFields() {
        property("SecureNoteFields missing 'content' throws DecodingError") <- forAll { (value: SecureNoteFields) in
            return assertMissingFieldThrowsDecodingError(value, removingKey: "content", type: SecureNoteFields.self)
        }
    }

    // MARK: - CreditCardFields (required: cardholderName, cardNumber, expirationDate, cvv)

    func testCreditCardFieldsMissingRequiredFields() {
        let requiredKeys = ["cardholderName", "cardNumber", "expirationDate", "cvv"]
        for key in requiredKeys {
            property("CreditCardFields missing '\(key)' throws DecodingError") <- forAll { (value: CreditCardFields) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: CreditCardFields.self)
            }
        }
    }

    // MARK: - IdentityDocumentFields (required: name, email, phone, address, customFields)

    func testIdentityDocumentFieldsMissingRequiredFields() {
        let requiredKeys = ["name", "email", "phone", "address", "customFields"]
        for key in requiredKeys {
            property("IdentityDocumentFields missing '\(key)' throws DecodingError") <- forAll { (value: IdentityDocumentFields) in
                return assertMissingFieldThrowsDecodingError(value, removingKey: key, type: IdentityDocumentFields.self)
            }
        }
    }

    // MARK: - EntryFields (discriminated union — missing "type" key)

    func testEntryFieldsMissingTypeKey() {
        property("EntryFields missing 'type' throws DecodingError") <- forAll { (value: EntryFields) in
            return assertMissingFieldThrowsDecodingError(value, removingKey: "type", type: EntryFields.self)
        }
    }
}
