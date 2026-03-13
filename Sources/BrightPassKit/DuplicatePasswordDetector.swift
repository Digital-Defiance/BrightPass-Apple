import Foundation

/// Detects duplicate passwords across login entries in a vault.
public struct DuplicatePasswordDetector {
    /// Checks whether the given password is shared by other login entries in the vault.
    /// - Parameters:
    ///   - entryId: The ID of the current entry to exclude from comparison.
    ///   - password: The password to check for duplicates.
    ///   - allEntries: All entries in the vault.
    /// - Returns: A `DuplicatePasswordResult` indicating whether duplicates exist and which entries share the password.
    public static func detect(entryId: String, password: String, allEntries: [VaultEntry]) -> DuplicatePasswordResult {
        let matchingIds = allEntries.filter { entry in
            guard entry.id != entryId else { return false }
            guard case .login(let loginFields) = entry.fields else { return false }
            return loginFields.password == password
        }.map(\.id)

        return DuplicatePasswordResult(
            isDuplicate: !matchingIds.isEmpty,
            duplicateCount: matchingIds.count,
            duplicateEntryIds: matchingIds
        )
    }
}
