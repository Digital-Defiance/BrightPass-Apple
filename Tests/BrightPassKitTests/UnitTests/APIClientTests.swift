// Unit tests for APIClient
// Validates: Requirements 1.3, 1.4, 1.6

import XCTest
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class APIClientTests: XCTestCase {

    private var mockKeychain: MockKeychainStore!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainStore()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeClient(environment: ConfigurationManager.Environment = .development) -> APIClient {
        let config = ConfigurationManager(environment: environment)
        return APIClient(configuration: config, keychain: mockKeychain, session: session)
    }

    // MARK: - 401 Handling

    /// On 401 response, the client clears the JWT and posts a sessionExpired notification.
    func test401ClearsJWTAndPostsNotification() async throws {
        try mockKeychain.saveJWT("expired-token")

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = try! JSONCoding.encoder.encode(
                APIError(status: 401, code: "unauthorized", message: "Token expired", details: nil)
            )
            return (response, body)
        }

        let client = makeClient()

        let expectation = expectation(forNotification: .sessionExpired, object: nil)

        do {
            let _: [VaultMetadata] = try await client.listVaults()
            XCTFail("Expected error")
        } catch {
            // Expected — 401 should throw
        }

        await fulfillment(of: [expectation], timeout: 2.0)

        // JWT should be cleared
        XCTAssertNil(try mockKeychain.loadJWT())
    }

    // MARK: - Base URL Configuration

    /// Development environment uses localhost:8080.
    func testDevelopmentBaseURL() async throws {
        MockURLProtocol.capturedRequests = []
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, try! JSONCoding.encoder.encode([VaultMetadata]()))
        }

        let client = makeClient(environment: .development)
        let _: [VaultMetadata] = try await client.listVaults()

        guard let url = MockURLProtocol.capturedRequests.last?.url else {
            XCTFail("No request captured")
            return
        }
        XCTAssertEqual(url.host, "localhost")
        XCTAssertEqual(url.port, 8080)
    }

    /// Production environment uses brightchain.org.
    func testProductionBaseURL() async throws {
        MockURLProtocol.capturedRequests = []
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, try! JSONCoding.encoder.encode([VaultMetadata]()))
        }

        let client = makeClient(environment: .production)
        let _: [VaultMetadata] = try await client.listVaults()

        guard let url = MockURLProtocol.capturedRequests.last?.url else {
            XCTFail("No request captured")
            return
        }
        XCTAssertEqual(url.host, "brightchain.org")
    }

    // MARK: - Malformed JSON Response

    /// A 200 response with invalid JSON produces a decoding failure.
    func testMalformedJSONProducesDecodingFailure() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let garbage = "not valid json {{{".data(using: .utf8)!
            return (response, garbage)
        }

        let client = makeClient()

        do {
            let _: [VaultMetadata] = try await client.listVaults()
            XCTFail("Expected decoding error")
        } catch is DecodingError {
            // Expected
        } catch {
            XCTFail("Expected DecodingError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - Non-2xx Without Valid APIError Body

    /// A non-2xx response with a non-APIError body produces a generic APIError.
    func testNon2xxWithInvalidBodyProducesGenericAPIError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            let garbage = "server error".data(using: .utf8)!
            return (response, garbage)
        }

        let client = makeClient()

        do {
            let _: [VaultMetadata] = try await client.listVaults()
            XCTFail("Expected error")
        } catch let error as APIError {
            XCTAssertEqual(error.status, 500)
            XCTAssertEqual(error.code, "http_error")
        } catch {
            XCTFail("Expected APIError, got \(type(of: error))")
        }
    }

    // MARK: - Content-Type Header

    /// Every request sets Content-Type to application/json.
    func testContentTypeHeader() async throws {
        MockURLProtocol.capturedRequests = []
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, try! JSONCoding.encoder.encode([VaultMetadata]()))
        }

        let client = makeClient()
        let _: [VaultMetadata] = try await client.listVaults()

        guard let captured = MockURLProtocol.capturedRequests.last else {
            XCTFail("No request captured")
            return
        }
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: - Successful Decode

    /// A valid 200 response with correct JSON decodes successfully.
    func testSuccessfulDecode() async throws {
        let expected = [
            VaultMetadata(id: "v1", name: "Personal", entryCount: 5)
        ]

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let wrapper: [String: Any] = [
                "success": true,
                "data": ["vaults": [["id": "v1", "name": "Personal", "entryCount": 5]]]
            ]
            let data = try! JSONSerialization.data(withJSONObject: wrapper)
            return (response, data)
        }

        let client = makeClient()
        let result: [VaultMetadata] = try await client.listVaults()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "v1")
        XCTAssertEqual(result.first?.name, "Personal")
        XCTAssertEqual(result.first?.entryCount, 5)
    }

    // MARK: - Network Timeout

    /// A network timeout (URLError.timedOut) propagates as URLError and maps to .networkUnavailable via ErrorMapper.
    func testNetworkTimeoutProducesNetworkUnavailableError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        let client = makeClient()

        do {
            let _: [VaultMetadata] = try await client.listVaults()
            XCTFail("Expected URLError(.timedOut)")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
            // Verify ErrorMapper converts this to .networkUnavailable
            let mapped = ErrorMapper.map(error)
            switch mapped {
            case .networkUnavailable:
                break // Expected
            default:
                XCTFail("Expected .networkUnavailable, got \(mapped)")
            }
        } catch {
            XCTFail("Expected URLError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - Void Endpoint (DELETE)

    /// A void endpoint (e.g. deleteVault) succeeds on 200 without decoding a body.
    func testVoidEndpointSucceeds() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = makeClient()

        try await client.deleteVault(id: "v1")
    }
}
