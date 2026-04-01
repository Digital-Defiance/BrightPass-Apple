// Unit tests for master password change and vault rename
// Validates: Requirements 22.3, 22.4, 22.5, 22.6, 23.3, 23.4

import XCTest
@testable import BrightPassKit

// MARK: - Mock APIClient

@available(macOS 14.0, iOS 17.0, *)
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    var changeMasterPasswordCalled = false
    var changeMasterPasswordError: Error?
    var renameVaultCalled = false
    var renameVaultError: Error?
    var renameVaultResult: VaultMetadata?

    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws {
        changeMasterPasswordCalled = true
        if let err = changeMasterPasswordError { throw err }
    }

    func renameVault(id: String, name: String) async throws -> VaultMetadata {
        renameVaultCalled = true
        if let err = renameVaultError { throw err }
        if let result = renameVaultResult { return result }
        return VaultMetadata(id: id, name: name)
    }

    func listVaults() async throws -> [VaultMetadata] { [] }

    // MARK: - Unused stubs
    func requestDirectLogin() async throws -> DirectLoginChallenge { fatalError() }
    func submitDirectChallenge(challenge: String, signature: String, username: String?, email: String?) async throws -> DirectChallengeResponse { fatalError() }
    func refreshToken() async throws -> DirectChallengeResponse { fatalError() }
    func logout() async throws { fatalError() }
    func verifyToken() async throws -> UserProfile { fatalError() }
    func login(username: String, password: String) async throws -> AuthResponse { fatalError() }
    func register(username: String, email: String, password: String) async throws -> AuthResponse { fatalError() }
    func createVault(name: String, masterPassword: String) async throws -> VaultMetadata { fatalError() }
    func openVault(id: String, masterPassword: String) async throws -> DecryptedVault { fatalError() }
    func deleteVault(id: String) async throws { fatalError() }
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
    func getAuditLog(vaultId: String) async throws -> [AuditLogEntry] { fatalError() }
    func shareVault(vaultId: String, memberId: String, permission: SharePermission) async throws { fatalError() }
    func revokeShare(vaultId: String, memberId: String) async throws { fatalError() }
    func listSharedMembers(vaultId: String) async throws -> [SharedMember] { fatalError() }
    func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws { fatalError() }
    func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig { fatalError() }
    func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault { fatalError() }
    func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}


// MARK: - Master Password Change Tests

@available(macOS 14.0, iOS 17.0, *)
final class MasterPasswordChangeTests: XCTestCase {

    /// Mismatched confirmation shows error without API call (Req 22.6)
    @MainActor
    func testMismatchedConfirmationShowsErrorWithoutAPICall() async {
        let mock = MockAPIClient()
        let keychain = MockKeychainStore()
        let vm = MasterPasswordChangeViewModel(apiClient: mock, keychainStore: keychain)

        vm.currentPassword = "oldPass"
        vm.newPassword = "newPass1"
        vm.confirmNewPassword = "newPass2"

        await vm.changePassword(vaultId: "v1")

        XCTAssertNotNil(vm.error)
        XCTAssertFalse(mock.changeMasterPasswordCalled)
        XCTAssertFalse(vm.isSuccess)
    }

    /// Successful password change updates biometric hash (Req 22.4)
    @MainActor
    func testSuccessfulChangeUpdatesBiometricHash() async {
        let mock = MockAPIClient()
        let keychain = MockKeychainStore()
        try! keychain.saveMasterPasswordHash("oldHash", vaultId: "v1", biometricProtected: true)

        let vm = MasterPasswordChangeViewModel(apiClient: mock, keychainStore: keychain)
        vm.currentPassword = "oldPass"
        vm.newPassword = "newPass"
        vm.confirmNewPassword = "newPass"

        await vm.changePassword(vaultId: "v1")

        XCTAssertTrue(vm.isSuccess)
        XCTAssertTrue(mock.changeMasterPasswordCalled)
        XCTAssertEqual(try! keychain.loadMasterPasswordHash(vaultId: "v1"), "newPass")
        XCTAssertTrue(try! keychain.hasBiometricProtectedHash(vaultId: "v1"))
    }

    /// Successful change without biometric does not touch keychain hash (Req 22.3)
    @MainActor
    func testSuccessfulChangeWithoutBiometricDoesNotStoreHash() async {
        let mock = MockAPIClient()
        let keychain = MockKeychainStore()
        // No biometric configured

        let vm = MasterPasswordChangeViewModel(apiClient: mock, keychainStore: keychain)
        vm.currentPassword = "oldPass"
        vm.newPassword = "newPass"
        vm.confirmNewPassword = "newPass"

        await vm.changePassword(vaultId: "v1")

        XCTAssertTrue(vm.isSuccess)
        XCTAssertNil(try! keychain.loadMasterPasswordHash(vaultId: "v1"))
    }

    /// Incorrect current password displays error (Req 22.5)
    @MainActor
    func testIncorrectCurrentPasswordDisplaysError() async {
        let mock = MockAPIClient()
        mock.changeMasterPasswordError = APIError(
            status: 403, code: "invalid_password",
            message: "Current password is incorrect", details: nil
        )
        let keychain = MockKeychainStore()

        let vm = MasterPasswordChangeViewModel(apiClient: mock, keychainStore: keychain)
        vm.currentPassword = "wrongPass"
        vm.newPassword = "newPass"
        vm.confirmNewPassword = "newPass"

        await vm.changePassword(vaultId: "v1")

        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isSuccess)
    }
}

// MARK: - Vault Rename Tests

@available(macOS 14.0, iOS 17.0, *)
final class VaultRenameTests: XCTestCase {

    /// Rename updates name in both vault list and vault detail (Req 23.3, 23.4)
    @MainActor
    func testRenameUpdatesNameInListAndDetail() async {
        let mock = MockAPIClient()
        let keychain = MockKeychainStore()

        let listVM = VaultListViewModel(apiClient: mock)
        listVM.vaults = [
            VaultMetadata(id: "v1", name: "Old Name")
        ]

        let detailVM = VaultDetailViewModel(apiClient: mock, keychainStore: keychain)
        detailVM.vault = DecryptedVault(id: "v1", name: "Old Name", entries: [])

        let renameVM = VaultRenameViewModel(apiClient: mock)
        renameVM.newName = "New Name"

        await renameVM.renameVault(vaultId: "v1", vaultListViewModel: listVM, vaultDetailViewModel: detailVM)

        XCTAssertNil(renameVM.error)
        XCTAssertTrue(mock.renameVaultCalled)
        XCTAssertEqual(listVM.vaults.first?.name, "New Name")
        XCTAssertEqual(detailVM.vault?.name, "New Name")
        XCTAssertEqual(listVM.vaults.count, 1)
    }

    /// Rename with empty name — the view disables the button, but VM still sends the request.
    /// API error is mapped and displayed.
    @MainActor
    func testRenameWithAPIErrorDisplaysError() async {
        let mock = MockAPIClient()
        mock.renameVaultError = APIError(
            status: 400, code: "validation_error",
            message: "Vault name cannot be empty", details: nil
        )

        let renameVM = VaultRenameViewModel(apiClient: mock)
        renameVM.newName = ""

        await renameVM.renameVault(vaultId: "v1")

        XCTAssertNotNil(renameVM.error)
    }

    /// Rename preserves vault count in the list (Req 23.4)
    @MainActor
    func testRenamePreservesVaultCount() async {
        let mock = MockAPIClient()

        let listVM = VaultListViewModel(apiClient: mock)
        listVM.vaults = [
            VaultMetadata(id: "v1", name: "Vault A"),
            VaultMetadata(id: "v2", name: "Vault B"),
            VaultMetadata(id: "v3", name: "Vault C"),
        ]

        let renameVM = VaultRenameViewModel(apiClient: mock)
        renameVM.newName = "Renamed B"

        await renameVM.renameVault(vaultId: "v2", vaultListViewModel: listVM)

        XCTAssertEqual(listVM.vaults.count, 3)
        XCTAssertEqual(listVM.vaults[1].name, "Renamed B")
        // Other vaults unchanged
        XCTAssertEqual(listVM.vaults[0].name, "Vault A")
        XCTAssertEqual(listVM.vaults[2].name, "Vault C")
    }
}
