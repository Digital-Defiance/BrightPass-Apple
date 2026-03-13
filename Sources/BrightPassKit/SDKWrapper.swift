import Foundation
import CryptoKit

// MARK: - MemberResult

/// Result of member creation or login via mnemonic.
public struct MemberResult: Sendable {
    public let id: String
    public let publicKey: Data
    public let privateKey: Data
    public let name: String
    public let email: String

    public init(id: String, publicKey: Data, privateKey: Data, name: String, email: String) {
        self.id = id
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.name = name
        self.email = email
    }
}

// MARK: - SDKWrapperProtocol

/// Protocol for BrightChain SDK operations needed by the auth flow.
public protocol SDKWrapperProtocol: Sendable {
    func validateMnemonic(_ mnemonic: String) -> Bool
    func generateMnemonic() -> String?
    func loginWithMnemonic(_ mnemonic: String, name: String, email: String) -> MemberResult?
    func signData(_ data: Data, withPrivateKey privateKey: Data) -> Data?
}

// MARK: - KeyringProtocol

/// Protocol for secure key encryption/decryption (Secure Enclave or AES-GCM fallback).
public protocol KeyringProtocol: Sendable {
    func encrypt(data: Data) throws -> Data
    func decrypt(encryptedData: Data) throws -> Data
    func deleteKey() throws
    func hasKey() -> Bool
}
