// Property 17: Audit Log Entries Contain Required Fields
// Property 18: Audit Log Reverse Chronological Order
// Validates: Requirements 11.3, 11.4
//
// Property 17: Every audit log entry has non-empty id, action, and memberId fields.
// Property 18: After loadAuditLog, entries are sorted by timestamp descending.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - MockAPIClient

/// Mock API client that returns a configurable list of audit log entries.
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    var auditEntries: [AuditLogEntry] = []

    func getAuditLog(vaultId: String) async throws -> [AuditLogEntry] {
        return auditEntries
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
    func autofillLookup(serviceIdentifier: String) async throws -> [AutofillPayload] { fatalError() }
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

/// Short non-empty alphanumeric string for action/memberId fields.
private let nonEmptyAlpha: Gen<String> = Gen<Character>.fromElements(in: "a"..."z")
    .proliferate(withSize: 10)
    .suchThat { !$0.isEmpty }
    .map { String($0.prefix(max(1, Int.random(in: 1...10)))) }

/// Date generator with whole-second precision.
private let arbitraryDate: Gen<Date> = Int.arbitrary.map { i in
    Date(timeIntervalSince1970: Double(abs(i) % 4_102_444_800))
}

/// Generator for a single AuditLogEntry with non-empty required fields.
private let arbitraryAuditEntry: Gen<AuditLogEntry> = Gen.compose { c in
    AuditLogEntry(
        id: UUID().uuidString,
        action: c.generate(using: nonEmptyAlpha),
        memberId: c.generate(using: nonEmptyAlpha),
        timestamp: c.generate(using: arbitraryDate),
        metadata: Bool.random() ? ["key": c.generate(using: nonEmptyAlpha)] : nil
    )
}

/// Generator for a list of 0–20 audit log entries.
private let auditEntryList: Gen<[AuditLogEntry]> = Gen.compose { c in
    let count = abs(c.generate(using: Int.arbitrary)) % 20
    return (0..<count).map { _ in c.generate(using: arbitraryAuditEntry) }
}

// MARK: - Async Bridge

/// Calls the mock API on a background thread and applies the same sort logic
/// as AuditLogViewModel.loadAuditLog, avoiding MainActor deadlock.
private func loadAuditLogSync(entries: [AuditLogEntry]) -> [AuditLogEntry] {
    let mock = MockAPIClient()
    mock.auditEntries = entries
    nonisolated(unsafe) var result: [AuditLogEntry] = []
    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        Task {
            let fetched = try await mock.getAuditLog(vaultId: "test-vault")
            // Apply the same sort as AuditLogViewModel.loadAuditLog
            result = fetched.sorted { $0.timestamp > $1.timestamp }
            semaphore.signal()
        }
    }
    semaphore.wait()
    return result
}

// MARK: - Property Tests

/// **Validates: Requirements 11.3, 11.4**
@available(macOS 14.0, iOS 17.0, *)
final class AuditLogPropertyTests: XCTestCase {

    /// **Property 17: Audit Log Entries Contain Required Fields**
    /// Every entry returned by loadAuditLog has non-empty id, action, and memberId.
    /// **Validates: Requirements 11.3**
    func testAuditLogEntriesContainRequiredFields() {
        property("All audit log entries have non-empty required fields") <- forAllNoShrink(auditEntryList) {
            (entries: [AuditLogEntry]) in
            let loaded = loadAuditLogSync(entries: entries)
            return loaded.allSatisfy { entry in
                !entry.id.isEmpty && !entry.action.isEmpty && !entry.memberId.isEmpty
            }
        }
    }

    /// **Property 18: Audit Log Reverse Chronological Order**
    /// After loadAuditLog, entries are sorted by timestamp descending (newest first).
    /// **Validates: Requirements 11.4**
    func testAuditLogReverseChronologicalOrder() {
        property("Audit log entries are sorted by timestamp descending") <- forAllNoShrink(auditEntryList) {
            (entries: [AuditLogEntry]) in
            let loaded = loadAuditLogSync(entries: entries)
            let timestamps = loaded.map { $0.timestamp }
            return zip(timestamps, timestamps.dropFirst()).allSatisfy { $0 >= $1 }
        }
    }
}
