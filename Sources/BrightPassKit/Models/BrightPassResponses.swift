import Foundation

// MARK: - Generic BrightPass API Response Wrappers
//
// All /api/brightpass/ endpoints return: { "success": Bool, "data": { ... } }
// These structs unwrap the nested response shapes.

/// Generic wrapper for `{ "success": Bool, "data": T }`.
struct BPResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
}

// MARK: - Data Payloads

struct VaultListData: Decodable {
    let vaults: [VaultMetadata]
}

struct VaultData: Decodable {
    let vault: VaultMetadata
}

struct OpenVaultPayload: Decodable {
    let metadata: VaultMetadata
    let propertyRecords: [EntryPropertyRecord]
}

struct OpenVaultData: Decodable {
    let vault: OpenVaultPayload
}

struct EntryListData: Decodable {
    let entries: [EntryPropertyRecord]
}

struct EntryData: Decodable {
    let entry: VaultEntry
}

struct SearchResultsData: Decodable {
    let results: [EntryPropertyRecord]
}

struct PasswordData: Decodable {
    let password: GeneratedPassword
}

struct TOTPCodeData: Decodable {
    let code: TotpCode
}

struct TOTPValidateData: Decodable {
    let valid: Bool
}

struct BreachData: Decodable {
    let breached: Bool
    let count: Int
}

struct ImportData: Decodable {
    let imported: Int?
    let skipped: Int?
    let errors: [String]?
}

struct AuditLogData: Decodable {
    let entries: [AuditLogEntry]
}
