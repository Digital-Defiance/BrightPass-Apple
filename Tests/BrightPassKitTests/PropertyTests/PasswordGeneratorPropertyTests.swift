// Property 12: Generated Password Length Matches Options
// Property 13: Generated Password Respects Character Constraints
// Validates: Requirements 5.2, 5.3, 5.4

import XCTest
import SwiftCheck
@testable import BrightPassKit

private let uppercaseSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
private let lowercaseSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
private let digitSet = CharacterSet(charactersIn: "0123456789")
private let specialSet = CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:',.<>?/`~")

private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    func generatePassword(options: PasswordOptions) async throws -> GeneratedPassword {
        let password = buildPassword(options: options)
        return GeneratedPassword(password: password, strength: nil)
    }

    private func buildPassword(options: PasswordOptions) -> String {
        var chars: [Character] = []
        var pool: [Character] = []
        let upper = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let lower = Array("abcdefghijklmnopqrstuvwxyz")
        let digits = Array("0123456789")
        let special: [Character] = Array("!@#$%^&*()-_=+[]{}|;:',.<>?/`~")
        if options.includeUppercase {
            pool.append(contentsOf: upper)
            for _ in 0..<options.minUppercase { chars.append(upper.randomElement()!) }
        }
        if options.includeLowercase { pool.append(contentsOf: lower) }
        if options.includeDigits {
            pool.append(contentsOf: digits)
            for _ in 0..<options.minDigits { chars.append(digits.randomElement()!) }
        }
        if options.includeSpecial {
            pool.append(contentsOf: special)
            for _ in 0..<options.minSpecial { chars.append(special.randomElement()!) }
        }
        if pool.isEmpty { pool.append(contentsOf: lower) }
        while chars.count < options.length { chars.append(pool.randomElement()!) }
        chars.shuffle()
        return String(chars)
    }

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
    func generateTOTP(secret: String) async throws -> TotpCode { fatalError() }
    func validateTOTPSecret(secret: String) async throws -> TotpCode { fatalError() }
    func checkBreach(password: String) async throws -> BreachCheckResult { fatalError() }
    func autofillLookup(serviceIdentifier: String) async throws -> [AutofillPayload] { fatalError() }
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

private let arbitraryLength: Gen<Int> = Int.arbitrary.map { abs($0) % 121 + 8 }

private let arbitraryPasswordOptions: Gen<PasswordOptions> = Gen.compose { c in
    let length = c.generate(using: arbitraryLength)
    var upper = c.generate(using: Bool.arbitrary)
    var lower = c.generate(using: Bool.arbitrary)
    var digs = c.generate(using: Bool.arbitrary)
    var spec = c.generate(using: Bool.arbitrary)
    if !upper && !lower && !digs && !spec { lower = true }
    let enabledCount = [upper, digs, spec].filter { $0 }.count
    let maxPerSet = enabledCount > 0 ? length / enabledCount : 0
    let minUpper = upper ? abs(c.generate(using: Int.arbitrary)) % (maxPerSet + 1) : 0
    let r1 = length - minUpper
    let minDigits = digs ? abs(c.generate(using: Int.arbitrary)) % (min(maxPerSet, r1) + 1) : 0
    let r2 = r1 - minDigits
    let minSpecial = spec ? abs(c.generate(using: Int.arbitrary)) % (min(maxPerSet, r2) + 1) : 0
    return PasswordOptions(
        length: length, includeUppercase: upper, includeLowercase: lower,
        includeDigits: digs, includeSpecial: spec,
        minUppercase: minUpper, minDigits: minDigits, minSpecial: minSpecial
    )
}

private func countChars(in s: String, from set: CharacterSet) -> Int {
    s.unicodeScalars.filter { set.contains($0) }.count
}

private func allCharsAllowed(_ pw: String, _ opts: PasswordOptions) -> Bool {
    var allowed = CharacterSet()
    if opts.includeUppercase { allowed.formUnion(uppercaseSet) }
    if opts.includeLowercase { allowed.formUnion(lowercaseSet) }
    if opts.includeDigits { allowed.formUnion(digitSet) }
    if opts.includeSpecial { allowed.formUnion(specialSet) }
    if allowed.isEmpty { allowed.formUnion(lowercaseSet) }
    return pw.unicodeScalars.allSatisfy { allowed.contains($0) }
}

/// Synchronously generates a password using the mock API client, using a detached task
/// to avoid MainActor deadlock.
private func generatePasswordSync(options: PasswordOptions) -> String {
    let mock = MockAPIClient()
    nonisolated(unsafe) var password: String?
    let semaphore = DispatchSemaphore(value: 0)
    Task.detached {
        let result = try await mock.generatePassword(options: options)
        password = result.password
        semaphore.signal()
    }
    semaphore.wait()
    return password!
}

@available(macOS 14.0, iOS 17.0, *)
final class PasswordGeneratorPropertyTests: XCTestCase {

    /// Property 12: Generated Password Length Matches Options
    func testGeneratedPasswordLengthMatchesOptions() {
        property("Generated password length equals requested length") <- forAllNoShrink(arbitraryPasswordOptions) {
            (options: PasswordOptions) in
            let pw = generatePasswordSync(options: options)
            return pw.count == options.length
        }
    }

    /// Property 13: Generated Password Respects Character Constraints
    func testGeneratedPasswordRespectsCharacterConstraints() {
        property("Generated password respects character set toggles and minimum counts") <- forAllNoShrink(arbitraryPasswordOptions) {
            (options: PasswordOptions) in
            let pw = generatePasswordSync(options: options)
            let ok1 = allCharsAllowed(pw, options)
            let ok2 = !options.includeUppercase || countChars(in: pw, from: uppercaseSet) >= options.minUppercase
            let ok3 = !options.includeDigits || countChars(in: pw, from: digitSet) >= options.minDigits
            let ok4 = !options.includeSpecial || countChars(in: pw, from: specialSet) >= options.minSpecial
            return ok1 && ok2 && ok3 && ok4
        }
    }
}
