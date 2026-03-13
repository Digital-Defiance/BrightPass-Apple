import Foundation
import CryptoKit
import secp256k1

/// SDK wrapper using secp256k1 with BIP39/BIP32/BIP44 key derivation.
/// Matches the brightchain-cpp Member implementation:
///   - BIP39 mnemonic → seed (PBKDF2-HMAC-SHA512, empty passphrase)
///   - BIP32 master key on secp256k1
///   - BIP44 derivation path: m/44'/60'/0'/0/0
///   - secp256k1 ECDSA signing (compact 64-byte signatures)
public final class FallbackSDKWrapper: SDKWrapperProtocol, @unchecked Sendable {

    public init() {}

    // MARK: - SDKWrapperProtocol

    public func generateMnemonic() -> String? {
        let wordList = BIP39.words.sorted()
        var entropy = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, entropy.count, &entropy) == errSecSuccess else { return nil }
        var words: [String] = []
        for i in 0..<12 {
            let index = Int(entropy[i % 16]) % wordList.count
            words.append(wordList[index])
        }
        return words.joined(separator: " ")
    }

    public func validateMnemonic(_ mnemonic: String) -> Bool {
        let words = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().split(separator: " ").map(String.init)
        guard words.count == 12 || words.count == 24 else { return false }
        return words.allSatisfy { BIP39.words.contains($0) }
    }

    public func loginWithMnemonic(_ mnemonic: String, name: String, email: String) -> MemberResult? {
        guard let privateKeyBytes = derivePrivateKey(from: mnemonic) else { return nil }
        guard let publicKeyBytes = derivePublicKey(from: privateKeyBytes) else { return nil }

        let idHash = SHA256.hash(data: publicKeyBytes)
        let memberId = Data(idHash).prefix(16).map { String(format: "%02x", $0) }.joined()

        return MemberResult(
            id: memberId,
            publicKey: publicKeyBytes,
            privateKey: privateKeyBytes,
            name: name,
            email: email
        )
    }

    public func signData(_ data: Data, withPrivateKey privateKey: Data) -> Data? {
        guard privateKey.count == 32 else { return nil }
        do {
            let key = try secp256k1.Signing.PrivateKey(dataRepresentation: Array(privateKey))
            // signature(for:) SHA256-hashes the data then calls secp256k1_ecdsa_sign.
            // The server does the same: sha256(data) then secp256k1.sign(hash, {prehash:false}).
            let signature = try key.signature(for: Array(data))
            // IMPORTANT: dataRepresentation is the internal libsecp256k1 format,
            // NOT the standard compact r||s. Use compactRepresentation for the
            // 64-byte format the server expects.
            return try signature.compactRepresentation
        } catch {
            return nil
        }
    }

    // MARK: - BIP39 Seed Derivation

    /// BIP39: mnemonic → 64-byte seed via PBKDF2-HMAC-SHA512 (2048 iterations, empty passphrase).
    /// Matches: mnemonic_to_seed(mnemonic, "", seed, nullptr)
    private func deriveSeed(from mnemonic: String) -> Data? {
        let password = Array(mnemonic.utf8)
        let salt = Array("mnemonic".utf8) // BIP39 uses "mnemonic" + passphrase; passphrase is empty
        return pbkdf2HMACSHA512(password: password, salt: salt, iterations: 2048, keyLength: 64)
    }

    // MARK: - BIP32/BIP44 Key Derivation

    /// Derives the private key using BIP44 path m/44'/60'/0'/0/0 on secp256k1.
    /// Matches the C++ brightchain implementation exactly.
    private func derivePrivateKey(from mnemonic: String) -> Data? {
        guard let seed = deriveSeed(from: mnemonic) else { return nil }

        // BIP32 master key: HMAC-SHA512 with key "Bitcoin seed"
        let masterKey = SymmetricKey(data: Array("Bitcoin seed".utf8))
        let masterHMAC = HMAC<SHA512>.authenticationCode(for: seed, using: masterKey)
        let masterData = Data(masterHMAC)
        var key = masterData.prefix(32)       // private key (IL)
        var chainCode = masterData.suffix(32)  // chain code (IR)

        // BIP44 derivation: m/44'/60'/0'/0/0
        let path: [UInt32] = [
            0x8000002C, // 44' (hardened)
            0x8000003C, // 60' (hardened)
            0x80000000, // 0'  (hardened)
            0x00000000, // 0   (normal)
            0x00000000  // 0   (normal)
        ]

        for index in path {
            guard let derived = deriveChild(parentKey: key, parentChainCode: chainCode, index: index) else {
                return nil
            }
            key = derived.key
            chainCode = derived.chainCode
        }

        return key
    }

    /// BIP32 child key derivation (CKD).
    private func deriveChild(parentKey: Data, parentChainCode: Data, index: UInt32) -> (key: Data, chainCode: Data)? {
        let hmacKey = SymmetricKey(data: parentChainCode)
        var data = Data()

        if index & 0x80000000 != 0 {
            // Hardened: 0x00 || parentKey || index
            data.append(0x00)
            data.append(parentKey)
        } else {
            // Normal: compressedPublicKey(parentKey) || index
            guard let pubKey = derivePublicKey(from: parentKey) else { return nil }
            data.append(pubKey)
        }

        // Append index as big-endian 4 bytes
        var indexBE = index.bigEndian
        data.append(Data(bytes: &indexBE, count: 4))

        let hmac = HMAC<SHA512>.authenticationCode(for: data, using: hmacKey)
        let hmacData = Data(hmac)
        let il = hmacData.prefix(32)
        let ir = hmacData.suffix(32)

        // child key = (IL + parentKey) mod n
        guard let childKey = addPrivateKeys(il, parentKey) else { return nil }
        return (childKey, ir)
    }

    /// Adds two 32-byte scalars mod the secp256k1 order n.
    private func addPrivateKeys(_ a: Data, _ b: Data) -> Data? {
        // secp256k1 order n
        let n: [UInt64] = [
            0xBFD25E8CD0364141,
            0xBAAEDCE6AF48A03B,
            0xFFFFFFFFFFFFFFFE,
            0xFFFFFFFFFFFFFFFF
        ]

        // Parse a and b as big-endian 256-bit integers, add, mod n
        var aWords = [UInt64](repeating: 0, count: 4)
        var bWords = [UInt64](repeating: 0, count: 4)
        a.withUnsafeBytes { ptr in
            for i in 0..<4 {
                aWords[3 - i] = ptr.load(fromByteOffset: i * 8, as: UInt64.self).bigEndian
            }
        }
        b.withUnsafeBytes { ptr in
            for i in 0..<4 {
                bWords[3 - i] = ptr.load(fromByteOffset: i * 8, as: UInt64.self).bigEndian
            }
        }

        // Add with carry
        var result = [UInt64](repeating: 0, count: 4)
        var carry: UInt64 = 0
        for i in 0..<4 {
            let (sum1, overflow1) = aWords[i].addingReportingOverflow(bWords[i])
            let (sum2, overflow2) = sum1.addingReportingOverflow(carry)
            result[i] = sum2
            carry = (overflow1 ? 1 : 0) + (overflow2 ? 1 : 0)
        }

        // Subtract n if result >= n
        var borrow: UInt64 = 0
        var reduced = [UInt64](repeating: 0, count: 4)
        for i in 0..<4 {
            let (diff1, underflow1) = result[i].subtractingReportingOverflow(n[i])
            let (diff2, underflow2) = diff1.subtractingReportingOverflow(borrow)
            reduced[i] = diff2
            borrow = (underflow1 ? 1 : 0) + (underflow2 ? 1 : 0)
        }

        let useReduced = (carry > 0) || (borrow == 0)
        let final_ = useReduced ? reduced : result

        // Convert back to big-endian Data
        var output = Data(count: 32)
        for i in 0..<4 {
            var val = final_[3 - i].bigEndian
            output.replaceSubrange(i*8..<(i+1)*8, with: Data(bytes: &val, count: 8))
        }
        return output
    }

    /// Derives the compressed public key (33 bytes) from a 32-byte private key using secp256k1.
    private func derivePublicKey(from privateKey: Data) -> Data? {
        do {
            let key = try secp256k1.Signing.PrivateKey(dataRepresentation: Array(privateKey))
            return Data(key.publicKey.dataRepresentation)
        } catch {
            return nil
        }
    }

    // MARK: - PBKDF2-HMAC-SHA512

    /// Pure-Swift PBKDF2-HMAC-SHA512 (BIP39 standard uses SHA512, not SHA256).
    private func pbkdf2HMACSHA512(password: [UInt8], salt: [UInt8], iterations: Int, keyLength: Int) -> Data? {
        let blockCount = (keyLength + 63) / 64 // SHA512 = 64 bytes per block
        var derivedKey = Data()

        for blockIndex in 1...blockCount {
            var saltWithIndex = salt
            saltWithIndex.append(UInt8((blockIndex >> 24) & 0xFF))
            saltWithIndex.append(UInt8((blockIndex >> 16) & 0xFF))
            saltWithIndex.append(UInt8((blockIndex >> 8) & 0xFF))
            saltWithIndex.append(UInt8(blockIndex & 0xFF))

            let symmetricKey = SymmetricKey(data: password)
            var u = Data(HMAC<SHA512>.authenticationCode(for: saltWithIndex, using: symmetricKey))
            var result = u

            for _ in 1..<iterations {
                u = Data(HMAC<SHA512>.authenticationCode(for: u, using: symmetricKey))
                for j in 0..<result.count {
                    result[j] ^= u[j]
                }
            }
            derivedKey.append(result)
        }
        return Data(derivedKey.prefix(keyLength))
    }
}
