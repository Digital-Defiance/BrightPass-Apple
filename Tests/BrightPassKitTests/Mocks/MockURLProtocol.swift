import Foundation

/// Custom `URLProtocol` subclass for intercepting and stubbing HTTP requests in tests.
/// Configure the static `requestHandler` closure before each test to return the desired response.
final class MockURLProtocol: URLProtocol {

    /// Handler called for every intercepted request.
    /// Return the desired `(HTTPURLResponse, Data)` or throw an error.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Collects all requests made during a test for assertion.
    static var capturedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        Self.capturedRequests.append(request)

        guard let handler = Self.requestHandler else {
            let error = NSError(domain: "MockURLProtocol", code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "No request handler set"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    /// Reset captured requests and handler between tests.
    static func reset() {
        requestHandler = nil
        capturedRequests = []
    }
}
