import Foundation

// MARK: - Session Expired Notification

public extension Notification.Name {
    /// Posted when the API client receives a 401 response, indicating the JWT has expired or is invalid.
    static let sessionExpired = Notification.Name("BrightPassSessionExpired")
}

// MARK: - APIClientProtocol

/// Defines all async methods for communicating with the BrightPass REST API.
public protocol APIClientProtocol: Sendable {

    // MARK: Auth — ECIES Direct Challenge (primary flow)

    func requestDirectLogin() async throws -> DirectLoginChallenge
    func submitDirectChallenge(challenge: String, signature: String, username: String?, email: String?) async throws -> DirectChallengeResponse
    func refreshToken() async throws -> DirectChallengeResponse
    func logout() async throws
    func verifyToken() async throws -> UserProfile

    // MARK: Auth — Password-based (fallback)

    func login(username: String, password: String) async throws -> AuthResponse
    func register(username: String, email: String, password: String) async throws -> AuthResponse

    // MARK: Vaults

    func listVaults() async throws -> [VaultMetadata]
    func createVault(name: String, masterPassword: String) async throws -> VaultMetadata
    func openVault(id: String, masterPassword: String) async throws -> DecryptedVault
    func deleteVault(id: String) async throws
    func renameVault(id: String, name: String) async throws -> VaultMetadata

    // MARK: Entries

    func listEntries(vaultId: String) async throws -> [EntryPropertyRecord]
    func getEntry(vaultId: String, entryId: String) async throws -> VaultEntry
    func createEntry(vaultId: String, entry: VaultEntry) async throws -> VaultEntry
    func updateEntry(vaultId: String, entryId: String, entry: VaultEntry) async throws -> VaultEntry
    func deleteEntry(vaultId: String, entryId: String) async throws
    func searchEntries(vaultId: String, query: String) async throws -> [EntryPropertyRecord]

    // MARK: Password Generation

    func generatePassword(options: PasswordOptions) async throws -> GeneratedPassword

    // MARK: TOTP

    func generateTOTP(secret: String) async throws -> TotpCode
    func validateTOTPSecret(secret: String) async throws -> TotpCode

    // MARK: Breach Check

    func checkBreach(password: String) async throws -> BreachCheckResult

    // MARK: Autofill

    func autofillLookup(serviceIdentifier: String) async throws -> [AutofillPayload]

    // MARK: Audit Log

    func getAuditLog(vaultId: String) async throws -> [AuditLogEntry]

    // MARK: Sharing

    func shareVault(vaultId: String, memberId: String, permission: SharePermission) async throws
    func revokeShare(vaultId: String, memberId: String) async throws
    func listSharedMembers(vaultId: String) async throws -> [SharedMember]

    // MARK: Emergency Access

    func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws
    func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig
    func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault

    // MARK: Import

    func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult

    // MARK: Master Password Change

    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws

    // MARK: Export

    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data
}


// MARK: - APIClient

/// Concrete API client backed by `URLSession`.
///
/// Reads the base URL from `ConfigurationManager` and attaches a JWT Bearer token
/// from `KeychainStoreProtocol` to every request. On 401 responses the JWT is cleared
/// and a `.sessionExpired` notification is posted.
@available(macOS 14.0, iOS 17.0, *)
public final class APIClient: APIClientProtocol, @unchecked Sendable {

    private let configuration: ConfigurationManager
    private let keychain: KeychainStoreProtocol
    private let session: URLSession

    public init(configuration: ConfigurationManager,
                keychain: KeychainStoreProtocol,
                session: URLSession = .shared) {
        self.configuration = configuration
        self.keychain = keychain
        self.session = session
    }

    // MARK: - Private Helpers

    /// Builds a `URLRequest` with the given path, method, and optional JSON body.
    /// Attaches the JWT Bearer token when available.
    private func buildRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = try keychain.loadJWT() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body
        return request
    }

    /// Executes a request, handles 401 (clears JWT + posts notification),
    /// maps non-2xx to `APIError`, and decodes the response body.
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        print("[APIClient] \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "nil")")
        if let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
            print("[APIClient] → \(bodyStr)")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            print("[APIClient] ✗ Response is not HTTPURLResponse")
            throw APIError(status: 0, code: "unknown", message: "Invalid response", details: nil)
        }

        let responseStr = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        print("[APIClient] ← \(http.statusCode) (\(data.count) bytes)")
        print("[APIClient] ← \(responseStr)")

        if http.statusCode == 401 {
            try? keychain.deleteJWT()
            await MainActor.run {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
            }
        }

        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? JSONCoding.decoder.decode(APIError.self, from: data) {
                throw apiError
            }
            throw APIError(status: http.statusCode, code: "http_error",
                           message: "Request failed with status \(http.statusCode)", details: nil)
        }

        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            print("[APIClient] ✗ Decoding \(T.self) failed: \(error)")
            throw error
        }
    }

    /// Executes a request that returns no meaningful body (e.g. DELETE, logout).
    private func executeVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(status: 0, code: "unknown", message: "Invalid response", details: nil)
        }

        if http.statusCode == 401 {
            try? keychain.deleteJWT()
            await MainActor.run {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
            }
        }

        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? JSONCoding.decoder.decode(APIError.self, from: data) {
                throw apiError
            }
            throw APIError(status: http.statusCode, code: "http_error",
                           message: "Request failed with status \(http.statusCode)", details: nil)
        }
    }

    /// Executes a request that returns raw `Data` (e.g. export).
    private func executeRaw(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(status: 0, code: "unknown", message: "Invalid response", details: nil)
        }

        if http.statusCode == 401 {
            try? keychain.deleteJWT()
            await MainActor.run {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
            }
        }

        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? JSONCoding.decoder.decode(APIError.self, from: data) {
                throw apiError
            }
            throw APIError(status: http.statusCode, code: "http_error",
                           message: "Request failed with status \(http.statusCode)", details: nil)
        }

        return data
    }


    // MARK: - Auth — ECIES Direct Challenge

    public func requestDirectLogin() async throws -> DirectLoginChallenge {
        let request = try buildRequest(path: "/api/user/request-direct-login", method: "POST")
        return try await execute(request)
    }

    public func submitDirectChallenge(challenge: String, signature: String, username: String?, email: String?) async throws -> DirectChallengeResponse {
        struct Body: Encodable {
            let challenge: String
            let signature: String
            let username: String?
            let email: String?
        }
        let body = try JSONCoding.encoder.encode(Body(challenge: challenge, signature: signature, username: username, email: email))
        let request = try buildRequest(path: "/api/user/direct-challenge", method: "POST", body: body)
        return try await execute(request)
    }

    public func refreshToken() async throws -> DirectChallengeResponse {
        let request = try buildRequest(path: "/api/user/refresh-token", method: "GET")
        return try await execute(request)
    }

    public func logout() async throws {
        let request = try buildRequest(path: "/api/user/logout", method: "POST")
        try await executeVoid(request)
    }

    public func verifyToken() async throws -> UserProfile {
        let request = try buildRequest(path: "/api/user/verify", method: "GET")
        let response: VerifyTokenResponse = try await execute(request)
        return response.user
    }

    // MARK: - Auth — Password-based (fallback)

    public func login(username: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let username: String; let password: String }
        let body = try JSONCoding.encoder.encode(Body(username: username, password: password))
        let request = try buildRequest(path: "/api/user/login", method: "POST", body: body)
        return try await execute(request)
    }

    public func register(username: String, email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let username: String; let email: String; let password: String }
        let body = try JSONCoding.encoder.encode(Body(username: username, email: email, password: password))
        let request = try buildRequest(path: "/api/user/register", method: "POST", body: body)
        return try await execute(request)
    }

    // MARK: - Vaults

    public func listVaults() async throws -> [VaultMetadata] {
        let request = try buildRequest(path: "/api/brightpass/vaults", method: "GET")
        let response: BPResponse<VaultListData> = try await execute(request)
        return response.data.vaults
    }

    public func createVault(name: String, masterPassword: String) async throws -> VaultMetadata {
        struct Body: Encodable { let name: String; let masterPassword: String }
        let body = try JSONCoding.encoder.encode(Body(name: name, masterPassword: masterPassword))
        let request = try buildRequest(path: "/api/brightpass/vaults", method: "POST", body: body)
        let response: BPResponse<VaultData> = try await execute(request)
        return response.data.vault
    }

    public func openVault(id: String, masterPassword: String) async throws -> DecryptedVault {
        struct Body: Encodable { let masterPassword: String }
        let body = try JSONCoding.encoder.encode(Body(masterPassword: masterPassword))
        let request = try buildRequest(path: "/api/brightpass/vaults/\(id)/open", method: "POST", body: body)
        let response: BPResponse<OpenVaultData> = try await execute(request)
        let payload = response.data.vault
        return DecryptedVault(
            id: payload.metadata.id,
            name: payload.metadata.name,
            entries: payload.propertyRecords
        )
    }

    public func deleteVault(id: String) async throws {
        let request = try buildRequest(path: "/api/brightpass/vaults/\(id)", method: "DELETE")
        try await executeVoid(request)
    }

    public func renameVault(id: String, name: String) async throws -> VaultMetadata {
        struct Body: Encodable { let name: String }
        let body = try JSONCoding.encoder.encode(Body(name: name))
        let request = try buildRequest(path: "/api/brightpass/vaults/\(id)/rename", method: "PUT", body: body)
        let response: BPResponse<VaultData> = try await execute(request)
        return response.data.vault
    }


    // MARK: - Entries

    public func listEntries(vaultId: String) async throws -> [EntryPropertyRecord] {
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/entries", method: "GET")
        let response: BPResponse<EntryListData> = try await execute(request)
        return response.data.entries
    }

    public func getEntry(vaultId: String, entryId: String) async throws -> VaultEntry {
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/entries/\(entryId)", method: "GET")
        let response: BPResponse<EntryData> = try await execute(request)
        return response.data.entry
    }

    public func createEntry(vaultId: String, entry: VaultEntry) async throws -> VaultEntry {
        struct CreateBody: Encodable {
            let type: EntryType
            let title: String
            let fields: EntryFields
            let tags: [String]
            let isFavorite: Bool
        }
        let payload = CreateBody(
            type: entry.type,
            title: entry.title,
            fields: entry.fields,
            tags: entry.tags,
            isFavorite: entry.isFavorite
        )
        let body = try JSONCoding.encoder.encode(payload)
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/entries", method: "POST", body: body)
        let response: BPResponse<EntryData> = try await execute(request)
        return response.data.entry
    }

    public func updateEntry(vaultId: String, entryId: String, entry: VaultEntry) async throws -> VaultEntry {
        let body = try JSONCoding.encoder.encode(entry)
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/entries/\(entryId)", method: "PUT", body: body)
        let response: BPResponse<EntryData> = try await execute(request)
        return response.data.entry
    }

    public func deleteEntry(vaultId: String, entryId: String) async throws {
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/entries/\(entryId)", method: "DELETE")
        try await executeVoid(request)
    }

    public func searchEntries(vaultId: String, query: String) async throws -> [EntryPropertyRecord] {
        struct Body: Encodable { let query: String }
        let body = try JSONCoding.encoder.encode(Body(query: query))
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/search", method: "POST", body: body)
        let response: BPResponse<SearchResultsData> = try await execute(request)
        return response.data.results
    }

    // MARK: - Password Generation

    public func generatePassword(options: PasswordOptions) async throws -> GeneratedPassword {
        let body = try JSONCoding.encoder.encode(options)
        let request = try buildRequest(path: "/api/brightpass/generate-password", method: "POST", body: body)
        let response: BPResponse<PasswordData> = try await execute(request)
        return response.data.password
    }

    // MARK: - TOTP

    public func generateTOTP(secret: String) async throws -> TotpCode {
        struct Body: Encodable { let secret: String }
        let body = try JSONCoding.encoder.encode(Body(secret: secret))
        let request = try buildRequest(path: "/api/brightpass/totp/generate", method: "POST", body: body)
        let response: BPResponse<TOTPCodeData> = try await execute(request)
        return response.data.code
    }

    public func validateTOTPSecret(secret: String) async throws -> TotpCode {
        struct Body: Encodable { let secret: String; let code: String? }
        let body = try JSONCoding.encoder.encode(Body(secret: secret, code: nil))
        let request = try buildRequest(path: "/api/brightpass/totp/validate", method: "POST", body: body)
        let response: BPResponse<TOTPCodeData> = try await execute(request)
        return response.data.code
    }

    // MARK: - Breach Check

    public func checkBreach(password: String) async throws -> BreachCheckResult {
        struct Body: Encodable { let password: String }
        let body = try JSONCoding.encoder.encode(Body(password: password))
        let request = try buildRequest(path: "/api/brightpass/breach-check", method: "POST", body: body)
        let response: BPResponse<BreachData> = try await execute(request)
        return BreachCheckResult(breached: response.data.breached, breachCount: response.data.count)
    }

    // MARK: - Autofill

    public func autofillLookup(serviceIdentifier: String) async throws -> [AutofillPayload] {
        struct Body: Encodable { let siteUrl: String }
        let body = try JSONCoding.encoder.encode(Body(siteUrl: serviceIdentifier))
        let request = try buildRequest(path: "/api/brightpass/autofill", method: "POST", body: body)
        return try await execute(request)
    }

    // MARK: - Audit Log

    public func getAuditLog(vaultId: String) async throws -> [AuditLogEntry] {
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/audit-log", method: "GET")
        let response: BPResponse<AuditLogData> = try await execute(request)
        return response.data.entries
    }


    // MARK: - Sharing

    public func shareVault(vaultId: String, memberId: String, permission: SharePermission) async throws {
        struct Body: Encodable { let recipientMemberIds: [String] }
        let body = try JSONCoding.encoder.encode(Body(recipientMemberIds: [memberId]))
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/share", method: "POST", body: body)
        try await executeVoid(request)
    }

    public func revokeShare(vaultId: String, memberId: String) async throws {
        struct Body: Encodable { let memberId: String }
        let body = try JSONCoding.encoder.encode(Body(memberId: memberId))
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/revoke-share", method: "POST", body: body)
        try await executeVoid(request)
    }

    public func listSharedMembers(vaultId: String) async throws -> [SharedMember] {
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/share", method: "GET")
        return try await execute(request)
    }

    // MARK: - Emergency Access

    public func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws {
        let body = try JSONCoding.encoder.encode(config)
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/emergency-access", method: "POST", body: body)
        try await executeVoid(request)
    }

    public func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig {
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/emergency-access", method: "GET")
        return try await execute(request)
    }

    public func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault {
        struct Body: Encodable { let shares: [String] }
        let body = try JSONCoding.encoder.encode(Body(shares: shares))
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/emergency-recover", method: "POST", body: body)
        let response: BPResponse<OpenVaultData> = try await execute(request)
        let payload = response.data.vault
        return DecryptedVault(
            id: payload.metadata.id,
            name: payload.metadata.name,
            entries: payload.propertyRecords
        )
    }

    // MARK: - Import

    public func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult {
        struct Body: Encodable { let format: ImportSource; let fileContent: String }
        let body = try JSONCoding.encoder.encode(Body(format: source, fileContent: fileData.base64EncodedString()))
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/import", method: "POST", body: body)
        let response: BPResponse<ImportData> = try await execute(request)
        return ImportResult(importedCount: response.data.imported ?? 0, errors: response.data.errors ?? [])
    }

    // MARK: - Master Password Change

    public func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws {
        struct Body: Encodable { let currentPassword: String; let newPassword: String }
        let body = try JSONCoding.encoder.encode(Body(currentPassword: currentPassword, newPassword: newPassword))
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/change-password", method: "PUT", body: body)
        try await executeVoid(request)
    }

    // MARK: - Export

    public func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data {
        let request = try buildRequest(path: "/api/brightpass/vaults/\(vaultId)/export?format=\(format.rawValue)", method: "GET")
        return try await executeRaw(request)
    }
}
