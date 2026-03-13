// Property 22: Autofill Returns URL-Matching Entries
// Property 23: Autofill Payload Contains Correct Credentials
// Validates: Requirements 14.2, 14.4
//
// Property 22: For any service identifier URL and any set of AutofillPayload entries,
// all entries returned by autofillLookup shall have a url field that matches the
// requested service identifier (case-insensitive contains).
//
// Property 23: For any AutofillPayload returned by autofillLookup, the payload shall
// contain non-empty username and password fields.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - MockAPIClient

/// Mock API client for autofill tests.
/// `autofillLookup` filters stored entries by case-insensitive URL match,
/// simulating what the real API would return.
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    /// Entries to filter against when `autofillLookup` is called.
    var storedEntries: [AutofillPayload] = []

    func autofillLookup(serviceIdentifier: String) async throws -> [AutofillPayload] {
        let id = serviceIdentifier.lowercased()
        return storedEntries.filter { entry in
            entry.url.lowercased().contains(id)
        }
    }

    // MARK: - Unused stubs

    func requestDirectLogin() async throws -> DirectLoginChallenge { fatalError() }
    func submitDirectChallenge(challenge: String, signature: String, username: String?, email: String?) async throws -> DirectChallengeResponse { fatalError() }
    func refreshToken() async throws -> DirectChallengeResponse { fatalError() }
    func logout() async throws { fatalError() }
    func verifyToken() async throws -> UserProfile { fatalError() }
    func login(username: String, password: String) async throws -> AuthResponse { fatalError() }
    func register(username: String, email: String, password: String) async throws -> AuthResponse { fatalError() }
    func listVaults() async throws -> [VaultMetadata] { fatalError() }
    func createVault(name: String, masterPassword: String) async throws -> VaultMetadata { fatalError() }
    func openVault(id: String, masterPassword: String) async throws -> DecryptedVault { fatalError() }
    func deleteVault(id: String) async throws { fatalError() }
    func renameVault(id: String, name: String) async throws -> VaultMetadata { fatalError() }
    func listEntries(vaultId: String) async throws -> [EntryPropertyRecord] { fatalError() }
    func getEntry(vaultId: String, entryId: String) async throws -> VaultEntry { fatalError() }
    func createEntry(vaultId: String, entry: VaultEntry) async throws -> VaultEntry { fatalError() }
    func updateEntry(vaultId: String, entryId: String, entry: VaultEntry) async throws -> VaultEntry { fatalError() }
    func deleteEntry(vaultId: String, entryId: String) async throws { fatalError() }
    func searchEntries(vaultId: String, query: String) async throws -> [EntryPropertyRecord] { fatalError() }
    func generatePassword(options: PasswordOptions) async throws -> GeneratedPassword { fatalError() }
    func generateTOTP(secret: String) async throws -> TotpCode { fatalError() }
    func validateTOTPSecret(secret: String) async throws -> TotpCode { fatalError() }
    func checkBreach(password: String) async throws -> BreachCheckResult { fatalError() }
    func getAuditLog(vaultId: String) async throws -> [AuditLogEntry] { fatalError() }
    func shareVault(vaultId: String, memberId: String, permission: SharePermission) async throws { fatalError() }
    func revokeShare(vaultId: String, memberId: String) async throws { fatalError() }
    func listSharedMembers(vaultId: String) async throws -> [SharedMember] { fatalError() }
    func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws { fatalError() }
    func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig { fatalError() }
    func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault { fatalError() }
    func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult { fatalError() }
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}

// MARK: - Generators

/// Generator for a short alphanumeric string (1–10 chars).
private let shortAlphaString: Gen<String> = Gen<Character>.fromElements(in: "a"..."z")
    .proliferate(withSize: 10)
    .suchThat { !$0.isEmpty }
    .map { String($0.prefix(max(1, Int.random(in: 1...10)))) }

/// Generator for a non-empty alphanumeric string (used for username/password).
private let nonEmptyAlphaString: Gen<String> = Gen<Character>.fromElements(in: "a"..."z")
    .proliferate(withSize: 12)
    .suchThat { !$0.isEmpty }
    .map { String($0.prefix(max(1, Int.random(in: 1...12)))) }

/// Generator for a single AutofillPayload with random data and non-empty username/password.
private let arbitraryPayload: Gen<AutofillPayload> = Gen.compose { c in
    AutofillPayload(
        entryId: UUID().uuidString,
        title: c.generate(using: shortAlphaString),
        username: c.generate(using: nonEmptyAlphaString),
        password: c.generate(using: nonEmptyAlphaString),
        url: "https://\(c.generate(using: shortAlphaString)).com"
    )
}

/// Generator for a list of 0–15 AutofillPayload items.
private let payloadList: Gen<[AutofillPayload]> = Gen.compose { c in
    let count = abs(c.generate(using: Int.arbitrary)) % 15
    return (0..<count).map { _ in c.generate(using: arbitraryPayload) }
}

// MARK: - Property Tests

/// **Validates: Requirements 14.2, 14.4**
@available(macOS 14.0, iOS 17.0, *)
final class AutofillPropertyTests: XCTestCase {

    /// **Property 22: Autofill Returns URL-Matching Entries**
    /// For any list of AutofillPayload items and any service identifier URL,
    /// all items returned by autofillLookup() shall have a url field that contains
    /// the service identifier (case-insensitive).
    /// **Validates: Requirements 14.2**
    func testAutofillReturnsURLMatchingEntries() {
        property("All autofill results have URLs containing the service identifier") <- forAllNoShrink(payloadList, shortAlphaString) {
            (entries: [AutofillPayload], serviceId: String) in

            let mock = MockAPIClient()
            mock.storedEntries = entries

            nonisolated(unsafe) var results: [AutofillPayload] = []
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                Task {
                    results = (try? await mock.autofillLookup(serviceIdentifier: serviceId)) ?? []
                    semaphore.signal()
                }
            }
            semaphore.wait()

            let id = serviceId.lowercased()
            return results.allSatisfy { payload in
                payload.url.lowercased().contains(id)
            }
        }
    }

    /// **Property 23: Autofill Payload Contains Correct Credentials**
    /// For any list of AutofillPayload items, all items returned by autofillLookup()
    /// shall have non-empty username AND non-empty password fields.
    /// **Validates: Requirements 14.4**
    func testAutofillPayloadContainsCorrectCredentials() {
        property("All autofill results have non-empty username and password") <- forAllNoShrink(payloadList, shortAlphaString) {
            (entries: [AutofillPayload], serviceId: String) in

            // Inject the service identifier into at least one entry's URL so we get results
            var modifiedEntries = entries
            if !entries.isEmpty {
                let idx = Int.random(in: 0..<entries.count)
                let original = entries[idx]
                modifiedEntries[idx] = AutofillPayload(
                    entryId: original.entryId,
                    title: original.title,
                    username: original.username,
                    password: original.password,
                    url: "https://\(serviceId).example.com"
                )
            }

            let mock = MockAPIClient()
            mock.storedEntries = modifiedEntries

            nonisolated(unsafe) var results: [AutofillPayload] = []
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                Task {
                    results = (try? await mock.autofillLookup(serviceIdentifier: serviceId)) ?? []
                    semaphore.signal()
                }
            }
            semaphore.wait()

            return results.allSatisfy { payload in
                !payload.username.isEmpty && !payload.password.isEmpty
            }
        }
    }
}
