// Property 1: JSON Serialization Round-Trip
// Validates: Requirements 1.7, 19.2
//
// For ALL Codable model types, encoding to JSON then decoding from JSON
// SHALL produce a value equal to the original.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Arbitrary Conformances: Simple Enums

extension EntryType: Arbitrary {
    public static var arbitrary: Gen<EntryType> {
        Gen.fromElements(of: Array(Self.allCases))
    }
}

extension SharePermission: Arbitrary {
    public static var arbitrary: Gen<SharePermission> {
        Gen.fromElements(of: [.readOnly, .readWrite])
    }
}

extension ImportSource: Arbitrary {
    public static var arbitrary: Gen<ImportSource> {
        Gen.fromElements(of: Array(Self.allCases))
    }
}

extension PasswordStrengthLevel: Arbitrary {
    public static var arbitrary: Gen<PasswordStrengthLevel> {
        Gen.fromElements(of: Array(Self.allCases))
    }
}

extension SortOption: Arbitrary {
    public static var arbitrary: Gen<SortOption> {
        Gen.fromElements(of: Array(Self.allCases))
    }
}

extension ExportFormat: Arbitrary {
    public static var arbitrary: Gen<ExportFormat> {
        Gen.fromElements(of: Array(Self.allCases))
    }
}

extension AppearanceMode: Arbitrary {
    public static var arbitrary: Gen<AppearanceMode> {
        Gen.fromElements(of: Array(Self.allCases))
    }
}


// MARK: - Helpers

/// Generate a Date truncated to whole seconds (ISO 8601 has second precision only).
private let arbitraryDate: Gen<Date> = Int.arbitrary.map { i in
    Date(timeIntervalSince1970: Double(abs(i) % 4_102_444_800)) // cap at ~2100
}

/// Generate an optional String.
private let optionalString: Gen<String?> = Gen<String?>.one(of: [
    String.arbitrary.map { Optional($0) },
    Gen.pure(nil)
])

/// Generate an optional Int.
private let optionalInt: Gen<Int?> = Gen<Int?>.one(of: [
    Int.arbitrary.map { Optional($0) },
    Gen.pure(nil)
])

/// Generate an optional [String].
private let optionalStringArray: Gen<[String]?> = Gen<[String]?>.one(of: [
    String.arbitrary.proliferate.map { Optional($0) },
    Gen.pure(nil)
])

/// Generate a small [String: String] dictionary (0–5 entries).
private let arbitraryStringDict: Gen<[String: String]> = Gen.zip(String.arbitrary, String.arbitrary)
    .proliferate
    .map { pairs in
        let capped = pairs.prefix(5)
        return Dictionary(capped.map { ($0.0, $0.1) }, uniquingKeysWith: { _, b in b })
    }

/// Generate an optional [String: String] dictionary.
private let optionalStringDict: Gen<[String: String]?> = Gen<[String: String]?>.one(of: [
    arbitraryStringDict.map { Optional($0) },
    Gen.pure(nil)
])


// MARK: - Arbitrary Conformances: Field Structs

extension LoginFields: Arbitrary {
    public static var arbitrary: Gen<LoginFields> {
        Gen.compose { c in
            LoginFields(
                siteURL: c.generate(),
                username: c.generate(),
                password: c.generate(),
                totpSecret: c.generate(using: optionalString)
            )
        }
    }
}

extension SecureNoteFields: Arbitrary {
    public static var arbitrary: Gen<SecureNoteFields> {
        String.arbitrary.map { SecureNoteFields(content: $0) }
    }
}

extension CreditCardFields: Arbitrary {
    public static var arbitrary: Gen<CreditCardFields> {
        Gen.compose { c in
            CreditCardFields(
                cardholderName: c.generate(),
                cardNumber: c.generate(),
                expirationDate: c.generate(),
                cvv: c.generate()
            )
        }
    }
}

extension IdentityDocumentFields: Arbitrary {
    public static var arbitrary: Gen<IdentityDocumentFields> {
        Gen.compose { c in
            IdentityDocumentFields(
                name: c.generate(),
                email: c.generate(),
                phone: c.generate(),
                address: c.generate(),
                customFields: c.generate(using: arbitraryStringDict)
            )
        }
    }
}

extension EntryFields: Arbitrary {
    public static var arbitrary: Gen<EntryFields> {
        Gen<EntryFields>.one(of: [
            LoginFields.arbitrary.map { .login($0) },
            SecureNoteFields.arbitrary.map { .secureNote($0) },
            CreditCardFields.arbitrary.map { .creditCard($0) },
            IdentityDocumentFields.arbitrary.map { .identityDocument($0) }
        ])
    }
}


// MARK: - Arbitrary Conformances: Struct Models

extension VaultMetadata: Arbitrary {
    public static var arbitrary: Gen<VaultMetadata> {
        Gen.compose { c in
            VaultMetadata(
                id: c.generate(),
                name: c.generate(),
                entryCount: c.generate()
            )
        }
    }
}

extension EntryPropertyRecord: Arbitrary {
    public static var arbitrary: Gen<EntryPropertyRecord> {
        Gen.compose { c in
            EntryPropertyRecord(
                id: c.generate(),
                title: c.generate(),
                type: c.generate(),
                tags: c.generate(),
                url: c.generate(using: optionalString),
                isFavorite: c.generate()
            )
        }
    }
}

extension DecryptedVault: Arbitrary {
    public static var arbitrary: Gen<DecryptedVault> {
        Gen.compose { c in
            DecryptedVault(
                id: c.generate(),
                name: c.generate(),
                entries: c.generate()
            )
        }
    }
}

extension VaultEntry: Arbitrary {
    public static var arbitrary: Gen<VaultEntry> {
        Gen.compose { c in
            let entryType: EntryType = c.generate()
            let fields: EntryFields
            switch entryType {
            case .login:
                fields = .login(c.generate())
            case .secureNote:
                fields = .secureNote(c.generate())
            case .creditCard:
                fields = .creditCard(c.generate())
            case .identityDocument:
                fields = .identityDocument(c.generate())
            }
            return VaultEntry(
                id: c.generate(),
                type: entryType,
                title: c.generate(),
                fields: fields,
                tags: c.generate(),
                isFavorite: c.generate(),
                createdAt: c.generate(using: arbitraryDate),
                updatedAt: c.generate(using: arbitraryDate)
            )
        }
    }
}

extension GeneratedPassword: Arbitrary {
    public static var arbitrary: Gen<GeneratedPassword> {
        Gen.compose { c in
            GeneratedPassword(
                password: c.generate(),
                strength: c.generate(using: optionalString)
            )
        }
    }
}

extension PasswordOptions: Arbitrary {
    public static var arbitrary: Gen<PasswordOptions> {
        Gen.compose { c in
            PasswordOptions(
                length: c.generate(),
                includeUppercase: c.generate(),
                includeLowercase: c.generate(),
                includeDigits: c.generate(),
                includeSpecial: c.generate(),
                minUppercase: c.generate(),
                minDigits: c.generate(),
                minSpecial: c.generate()
            )
        }
    }
}

extension TotpCode: Arbitrary {
    public static var arbitrary: Gen<TotpCode> {
        Gen.compose { c in
            TotpCode(
                code: c.generate(),
                remainingSeconds: c.generate(),
                period: c.generate()
            )
        }
    }
}

extension BreachCheckResult: Arbitrary {
    public static var arbitrary: Gen<BreachCheckResult> {
        Gen.compose { c in
            BreachCheckResult(
                breached: c.generate(),
                breachCount: c.generate(using: optionalInt)
            )
        }
    }
}

extension AutofillPayload: Arbitrary {
    public static var arbitrary: Gen<AutofillPayload> {
        Gen.compose { c in
            AutofillPayload(
                entryId: c.generate(),
                title: c.generate(),
                username: c.generate(),
                password: c.generate(),
                url: c.generate()
            )
        }
    }
}

extension AuditLogEntry: Arbitrary {
    public static var arbitrary: Gen<AuditLogEntry> {
        Gen.compose { c in
            AuditLogEntry(
                id: c.generate(),
                action: c.generate(),
                memberId: c.generate(),
                timestamp: c.generate(using: arbitraryDate),
                metadata: c.generate(using: optionalStringDict)
            )
        }
    }
}

extension SharedMember: Arbitrary {
    public static var arbitrary: Gen<SharedMember> {
        Gen.compose { c in
            SharedMember(
                id: c.generate(),
                memberId: c.generate(),
                permission: c.generate()
            )
        }
    }
}

extension EmergencyAccessConfig: Arbitrary {
    public static var arbitrary: Gen<EmergencyAccessConfig> {
        Gen.compose { c in
            EmergencyAccessConfig(
                totalShares: c.generate(),
                threshold: c.generate(),
                trustees: c.generate()
            )
        }
    }
}

extension ImportResult: Arbitrary {
    public static var arbitrary: Gen<ImportResult> {
        Gen.compose { c in
            ImportResult(
                importedCount: c.generate(),
                errors: c.generate()
            )
        }
    }
}

extension AuthToken: Arbitrary {
    public static var arbitrary: Gen<AuthToken> {
        Gen.compose { c in
            AuthToken(
                token: c.generate(),
                expiresAt: c.generate(using: arbitraryDate)
            )
        }
    }
}

extension APIError: Arbitrary {
    public static var arbitrary: Gen<APIError> {
        Gen.compose { c in
            APIError(
                status: c.generate(),
                code: c.generate(),
                message: c.generate(),
                details: c.generate(using: optionalStringArray)
            )
        }
    }
}

extension RecentEntryReference: Arbitrary {
    public static var arbitrary: Gen<RecentEntryReference> {
        Gen.compose { c in
            RecentEntryReference(
                id: c.generate(),
                entryId: c.generate(),
                vaultId: c.generate(),
                title: c.generate(),
                accessedAt: c.generate(using: arbitraryDate)
            )
        }
    }
}


// MARK: - Property Tests

/// **Validates: Requirements 1.7, 19.2**
/// Property 1: JSON Serialization Round-Trip
/// For ALL Codable model types, encoding to JSON then decoding from JSON
/// produces a value equal to the original.
final class JSONRoundTripPropertyTests: XCTestCase {

    // MARK: Simple Enums

    func testEntryTypeRoundTrip() {
        property("EntryType round-trips through JSON") <- forAll { (value: EntryType) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(EntryType.self, from: data)
            return value == decoded
        }
    }

    func testSharePermissionRoundTrip() {
        property("SharePermission round-trips through JSON") <- forAll { (value: SharePermission) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(SharePermission.self, from: data)
            return value == decoded
        }
    }

    func testImportSourceRoundTrip() {
        property("ImportSource round-trips through JSON") <- forAll { (value: ImportSource) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(ImportSource.self, from: data)
            return value == decoded
        }
    }

    func testPasswordStrengthLevelRoundTrip() {
        property("PasswordStrengthLevel round-trips through JSON") <- forAll { (value: PasswordStrengthLevel) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(PasswordStrengthLevel.self, from: data)
            return value == decoded
        }
    }

    func testSortOptionRoundTrip() {
        property("SortOption round-trips through JSON") <- forAll { (value: SortOption) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(SortOption.self, from: data)
            return value == decoded
        }
    }

    func testExportFormatRoundTrip() {
        property("ExportFormat round-trips through JSON") <- forAll { (value: ExportFormat) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(ExportFormat.self, from: data)
            return value == decoded
        }
    }

    func testAppearanceModeRoundTrip() {
        property("AppearanceMode round-trips through JSON") <- forAll { (value: AppearanceMode) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(AppearanceMode.self, from: data)
            return value == decoded
        }
    }

    // MARK: Field Structs

    func testLoginFieldsRoundTrip() {
        property("LoginFields round-trips through JSON") <- forAll { (value: LoginFields) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(LoginFields.self, from: data)
            return value == decoded
        }
    }

    func testSecureNoteFieldsRoundTrip() {
        property("SecureNoteFields round-trips through JSON") <- forAll { (value: SecureNoteFields) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(SecureNoteFields.self, from: data)
            return value == decoded
        }
    }

    func testCreditCardFieldsRoundTrip() {
        property("CreditCardFields round-trips through JSON") <- forAll { (value: CreditCardFields) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(CreditCardFields.self, from: data)
            return value == decoded
        }
    }

    func testIdentityDocumentFieldsRoundTrip() {
        property("IdentityDocumentFields round-trips through JSON") <- forAll { (value: IdentityDocumentFields) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(IdentityDocumentFields.self, from: data)
            return value == decoded
        }
    }

    func testEntryFieldsRoundTrip() {
        property("EntryFields round-trips through JSON") <- forAll { (value: EntryFields) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(EntryFields.self, from: data)
            return value == decoded
        }
    }

    // MARK: Struct Models

    func testVaultMetadataRoundTrip() {
        property("VaultMetadata round-trips through JSON") <- forAll { (value: VaultMetadata) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(VaultMetadata.self, from: data)
            return value == decoded
        }
    }

    func testEntryPropertyRecordRoundTrip() {
        property("EntryPropertyRecord round-trips through JSON") <- forAll { (value: EntryPropertyRecord) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(EntryPropertyRecord.self, from: data)
            return value == decoded
        }
    }

    func testDecryptedVaultRoundTrip() {
        property("DecryptedVault round-trips through JSON") <- forAll { (value: DecryptedVault) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(DecryptedVault.self, from: data)
            return value == decoded
        }
    }

    func testVaultEntryRoundTrip() {
        property("VaultEntry round-trips through JSON") <- forAll { (value: VaultEntry) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(VaultEntry.self, from: data)
            return value == decoded
        }
    }

    func testGeneratedPasswordRoundTrip() {
        property("GeneratedPassword round-trips through JSON") <- forAll { (value: GeneratedPassword) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(GeneratedPassword.self, from: data)
            return value == decoded
        }
    }

    func testPasswordOptionsRoundTrip() {
        property("PasswordOptions round-trips through JSON") <- forAll { (value: PasswordOptions) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(PasswordOptions.self, from: data)
            return value == decoded
        }
    }

    func testTotpCodeRoundTrip() {
        property("TotpCode round-trips through JSON") <- forAll { (value: TotpCode) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(TotpCode.self, from: data)
            return value == decoded
        }
    }

    func testBreachCheckResultRoundTrip() {
        property("BreachCheckResult round-trips through JSON") <- forAll { (value: BreachCheckResult) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(BreachCheckResult.self, from: data)
            return value == decoded
        }
    }

    func testAutofillPayloadRoundTrip() {
        property("AutofillPayload round-trips through JSON") <- forAll { (value: AutofillPayload) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(AutofillPayload.self, from: data)
            return value == decoded
        }
    }

    func testAuditLogEntryRoundTrip() {
        property("AuditLogEntry round-trips through JSON") <- forAll { (value: AuditLogEntry) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(AuditLogEntry.self, from: data)
            return value == decoded
        }
    }

    func testSharedMemberRoundTrip() {
        property("SharedMember round-trips through JSON") <- forAll { (value: SharedMember) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(SharedMember.self, from: data)
            return value == decoded
        }
    }

    func testEmergencyAccessConfigRoundTrip() {
        property("EmergencyAccessConfig round-trips through JSON") <- forAll { (value: EmergencyAccessConfig) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(EmergencyAccessConfig.self, from: data)
            return value == decoded
        }
    }

    func testImportResultRoundTrip() {
        property("ImportResult round-trips through JSON") <- forAll { (value: ImportResult) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(ImportResult.self, from: data)
            return value == decoded
        }
    }

    func testAuthTokenRoundTrip() {
        property("AuthToken round-trips through JSON") <- forAll { (value: AuthToken) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(AuthToken.self, from: data)
            return value == decoded
        }
    }

    func testAPIErrorRoundTrip() {
        property("APIError round-trips through JSON") <- forAll { (value: APIError) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(APIError.self, from: data)
            return value == decoded
        }
    }

    func testRecentEntryReferenceRoundTrip() {
        property("RecentEntryReference round-trips through JSON") <- forAll { (value: RecentEntryReference) in
            let data = try! JSONCoding.encoder.encode(value)
            let decoded = try! JSONCoding.decoder.decode(RecentEntryReference.self, from: data)
            return value == decoded
        }
    }
}
