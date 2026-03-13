import XCTest
@testable import BrightPassKit

/// Verifies that FallbackSDKWrapper key derivation matches the brightchain-cpp test vectors.
/// Mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
/// Expected derivation path: m/44'/60'/0'/0/0 on secp256k1
@available(macOS 14.0, iOS 17.0, *)
final class KeyDerivationVerificationTest: XCTestCase {

    func testKeyDerivationMatchesCppTestVectors() {
        let wrapper = FallbackSDKWrapper()
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        // From brightchain-cpp/test_vectors_mnemonic_voting.json
        let expectedPrivateKey: [UInt8] = [
            26, 180, 44, 196, 18, 182, 24, 189, 234, 58, 89, 158, 60, 155, 174, 25,
            158, 191, 3, 8, 149, 176, 57, 233, 219, 30, 48, 218, 251, 18, 183, 39
        ]
        let expectedPublicKey: [UInt8] = [
            2, 55, 176, 187, 122, 130, 136, 211, 142, 212, 154, 82, 75, 93, 201, 140,
            255, 62, 181, 202, 130, 76, 159, 157, 192, 223, 219, 61, 156, 214, 0, 242, 153
        ]

        guard let result = wrapper.loginWithMnemonic(mnemonic, name: "Test User", email: "test@example.com") else {
            XCTFail("loginWithMnemonic returned nil")
            return
        }

        let derivedPrivate = Array(result.privateKey)
        let derivedPublic = Array(result.publicKey)

        print("Expected private: \(expectedPrivateKey.map { String(format: "%02x", $0) }.joined())")
        print("Derived  private: \(derivedPrivate.map { String(format: "%02x", $0) }.joined())")
        print("Expected public:  \(expectedPublicKey.map { String(format: "%02x", $0) }.joined())")
        print("Derived  public:  \(derivedPublic.map { String(format: "%02x", $0) }.joined())")

        XCTAssertEqual(derivedPrivate, expectedPrivateKey, "Private key must match C++ test vector")
        XCTAssertEqual(derivedPublic, expectedPublicKey, "Public key must match C++ test vector")
    }
}
