// Property 2: JWT Bearer Token Attachment
// Property 3: API Error Decoding Preserves Fields
// Validates: Requirements 1.2, 1.6

import XCTest
import SwiftCheck
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class APIClientPropertyTests: XCTestCase {

    private var mockKeychain: MockKeychainStore!
    private var configuration: ConfigurationManager!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainStore()
        configuration = ConfigurationManager(environment: .development)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Property 2: JWT Bearer Token Attachment

    /// For any non-empty JWT string stored in the keychain, every request made by APIClient
    /// includes an Authorization header with value "Bearer <token>".
    func testJWTBearerTokenAttachment() {
        property("Every request includes Bearer token from keychain") <- forAll(
            String.arbitrary.suchThat { !$0.isEmpty }
        ) { [self] (token: String) in
            // Store the JWT
            try! self.mockKeychain.saveJWT(token)

            // Stub a 200 response with valid BPResponse<VaultListData> JSON for listVaults
            MockURLProtocol.capturedRequests = []
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let wrapper: [String: Any] = [
                    "success": true,
                    "data": ["vaults": [] as [[String: Any]]]
                ]
                let body = try! JSONSerialization.data(withJSONObject: wrapper)
                return (response, body)
            }

            let client = APIClient(configuration: self.configuration,
                                   keychain: self.mockKeychain,
                                   session: self.session)

            // Fire a request using async bridging via XCTestExpectation
            let exp = self.expectation(description: "request")
            Task {
                let _ = try? await client.listVaults() as [VaultMetadata]
                exp.fulfill()
            }
            self.wait(for: [exp], timeout: 5.0)

            guard let captured = MockURLProtocol.capturedRequests.last else {
                return false
            }

            let authHeader = captured.value(forHTTPHeaderField: "Authorization")
            return authHeader == "Bearer \(token)"
        }
    }

    /// When no JWT is stored, requests should not include an Authorization header.
    func testNoJWTOmitsAuthorizationHeader() async throws {
        // Ensure keychain is empty
        try mockKeychain.deleteJWT()

        MockURLProtocol.capturedRequests = []
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let wrapper: [String: Any] = [
                "success": true,
                "data": ["vaults": [] as [[String: Any]]]
            ]
            let body = try! JSONSerialization.data(withJSONObject: wrapper)
            return (response, body)
        }

        let client = APIClient(configuration: configuration,
                               keychain: mockKeychain,
                               session: session)

        let _: [VaultMetadata] = try await client.listVaults()

        guard let captured = MockURLProtocol.capturedRequests.last else {
            XCTFail("No request captured")
            return
        }

        XCTAssertNil(captured.value(forHTTPHeaderField: "Authorization"))
    }

    // MARK: - Property 3: API Error Decoding Preserves Fields

    /// For any APIError, encoding to JSON then decoding produces an equal value.
    /// (This is also covered in JSONRoundTripPropertyTests, but here we verify it
    /// specifically in the context of the APIClient's error handling path.)
    func testAPIErrorDecodingPreservesFields() {
        property("APIError JSON round-trip preserves all fields") <- forAll { (error: APIError) in
            let data = try! JSONCoding.encoder.encode(error)
            let decoded = try! JSONCoding.decoder.decode(APIError.self, from: data)
            return error == decoded
        }
    }

    /// When the server returns a non-2xx response with a valid APIError JSON body,
    /// the client throws an APIError with the same fields.
    func testNon2xxResponseDecodesAPIError() async {
        let originalError = APIError(status: 422, code: "validation_error",
                                     message: "Invalid input", details: ["field required"])

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 422,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = try! JSONCoding.encoder.encode(originalError)
            return (response, body)
        }

        let client = APIClient(configuration: configuration,
                               keychain: mockKeychain,
                               session: session)

        do {
            let _: [VaultMetadata] = try await client.listVaults()
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, originalError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
