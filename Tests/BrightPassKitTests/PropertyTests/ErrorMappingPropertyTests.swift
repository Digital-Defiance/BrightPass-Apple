// Property 26: HTTP Error Mapping Produces Correct Category
// Property 27: Recoverable Errors Are Retryable
// Validates: Requirements 17.1, 17.2, 17.3, 17.4
//
// Property 26: For any URLError with timeout/connectivity codes, ErrorMapper produces
// .networkUnavailable. For any APIError with status in [500,599], ErrorMapper produces
// .serverError. For any APIError with status in [400,499] (excluding 401), ErrorMapper
// produces .validationError. For APIError with status 401, ErrorMapper produces .sessionExpired.
//
// Property 27: .networkUnavailable and .serverError have isRetryable == true.
// .sessionExpired, .validationError, .decodingFailure, .unknown have isRetryable == false.

import XCTest
import SwiftCheck
@testable import BrightPassKit

// MARK: - Generators

/// Known URLError codes that map to the "specific" networkUnavailable message.
private let connectivityCodes: [URLError.Code] = [
    .timedOut, .notConnectedToInternet, .networkConnectionLost
]

/// A broader set of URLError codes (non-connectivity) to exercise the default branch.
private let otherURLErrorCodes: [URLError.Code] = [
    .cancelled, .badURL, .unsupportedURL, .cannotFindHost,
    .cannotConnectToHost, .dnsLookupFailed, .httpTooManyRedirects,
    .resourceUnavailable, .redirectToNonExistentLocation,
    .badServerResponse, .zeroByteResource, .cannotDecodeRawData,
    .cannotDecodeContentData, .cannotParseResponse,
    .secureConnectionFailed, .serverCertificateHasBadDate,
    .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
    .serverCertificateNotYetValid, .clientCertificateRejected,
    .clientCertificateRequired, .cannotLoadFromNetwork,
    .downloadDecodingFailedMidStream, .downloadDecodingFailedToComplete
]

/// All URLError codes we test against.
private let allURLErrorCodes: [URLError.Code] = connectivityCodes + otherURLErrorCodes

/// Generator for connectivity URLError codes.
private let connectivityCodeGen: Gen<URLError.Code> = Gen.fromElements(of: connectivityCodes)

/// Generator for non-connectivity URLError codes.
private let otherURLErrorCodeGen: Gen<URLError.Code> = Gen.fromElements(of: otherURLErrorCodes)

/// Generator for any URLError code from our test set.
private let anyURLErrorCodeGen: Gen<URLError.Code> = Gen.fromElements(of: allURLErrorCodes)

/// Generator for APIError with status in [500, 599] (server errors).
private let serverStatusGen: Gen<Int> = Int.arbitrary.map { i in 500 + (abs(i) % 100) }

/// Generator for APIError with status 401 (session expired).
private let unauthorizedStatusGen: Gen<Int> = Gen.pure(401)

/// Generator for APIError with status in [400, 499] excluding 401 (validation errors).
private let validationStatusGen: Gen<Int> = Int.arbitrary
    .suchThat { i in let s = 400 + (abs(i) % 100); return s != 401 }
    .map { i in 400 + (abs(i) % 100) }

/// Generator for APIError with status outside [400, 599] (unknown).
private let unknownAPIStatusGen: Gen<Int> = Gen<Int>.one(of: [
    Int.arbitrary.map { i in abs(i) % 400 },          // 0..<400
    Int.arbitrary.map { i in 600 + (abs(i) % 400) }   // 600+
])

/// Helper to build an APIError with a given status generator.
private func apiErrorGen(statusGen: Gen<Int>) -> Gen<APIError> {
    Gen.compose { c in
        APIError(
            status: c.generate(using: statusGen),
            code: c.generate(),
            message: c.generate(),
            details: c.generate(using: Gen<[String]?>.one(of: [
                String.arbitrary.proliferate.map { Optional($0) },
                Gen.pure(nil)
            ]))
        )
    }
}

// MARK: - Helper to classify AppError

private enum AppErrorCategory: Equatable {
    case networkUnavailable
    case sessionExpired
    case validationError
    case serverError
    case decodingFailure
    case unknown
}

private func category(of error: AppError) -> AppErrorCategory {
    switch error {
    case .networkUnavailable: return .networkUnavailable
    case .sessionExpired: return .sessionExpired
    case .validationError: return .validationError
    case .serverError: return .serverError
    case .decodingFailure: return .decodingFailure
    case .unknown: return .unknown
    }
}

// MARK: - Property Tests

/// **Validates: Requirements 17.1, 17.2, 17.3**
/// Property 26: HTTP Error Mapping Produces Correct Category
///
/// **Validates: Requirements 17.4**
/// Property 27: Recoverable Errors Are Retryable
final class ErrorMappingPropertyTests: XCTestCase {

    // MARK: - Property 26: HTTP Error Mapping Produces Correct Category

    func testConnectivityURLErrorsMappedToNetworkUnavailable() {
        property("Connectivity URLError codes map to .networkUnavailable") <- forAllNoShrink(connectivityCodeGen) { code in
            let urlError = URLError(code)
            let result = ErrorMapper.map(urlError)
            return category(of: result) == .networkUnavailable
        }
    }

    func testOtherURLErrorsMappedToNetworkUnavailable() {
        property("Non-connectivity URLError codes also map to .networkUnavailable") <- forAllNoShrink(otherURLErrorCodeGen) { code in
            let urlError = URLError(code)
            let result = ErrorMapper.map(urlError)
            return category(of: result) == .networkUnavailable
        }
    }

    func testServerStatusAPIErrorMappedToServerError() {
        property("APIError with status 500-599 maps to .serverError") <- forAllNoShrink(apiErrorGen(statusGen: serverStatusGen)) { apiError in
            let result = ErrorMapper.map(apiError)
            return category(of: result) == .serverError
        }
    }

    func testUnauthorizedAPIErrorMappedToSessionExpired() {
        property("APIError with status 401 maps to .sessionExpired") <- forAllNoShrink(apiErrorGen(statusGen: unauthorizedStatusGen)) { apiError in
            let result = ErrorMapper.map(apiError)
            return category(of: result) == .sessionExpired
        }
    }

    func testValidationStatusAPIErrorMappedToValidationError() {
        property("APIError with status 400-499 (excl 401) maps to .validationError") <- forAllNoShrink(apiErrorGen(statusGen: validationStatusGen)) { apiError in
            let result = ErrorMapper.map(apiError)
            return category(of: result) == .validationError
        }
    }

    func testUnknownAPIStatusMappedToUnknown() {
        property("APIError with status outside 400-599 maps to .unknown") <- forAllNoShrink(apiErrorGen(statusGen: unknownAPIStatusGen)) { apiError in
            let result = ErrorMapper.map(apiError)
            return category(of: result) == .unknown
        }
    }

    func testValidationErrorPreservesDetails() {
        let detailsGen = String.arbitrary.proliferate.suchThat { !$0.isEmpty }
        let gen = Gen.compose { (c: GenComposer) -> APIError in
            let status = c.generate(using: validationStatusGen)
            return APIError(
                status: status,
                code: c.generate(),
                message: c.generate(),
                details: c.generate(using: detailsGen.map { Optional($0) })
            )
        }
        property("Validation errors preserve detail messages from APIError") <- forAllNoShrink(gen) { apiError in
            let result = ErrorMapper.map(apiError)
            switch result {
            case .validationError(let messages):
                return messages == (apiError.details ?? [apiError.message])
            default:
                return false
            }
        }
    }

    // MARK: - Property 27: Recoverable Errors Are Retryable

    func testNetworkUnavailableIsRetryable() {
        property(".networkUnavailable errors are retryable") <- forAllNoShrink(anyURLErrorCodeGen) { code in
            let urlError = URLError(code)
            let result = ErrorMapper.map(urlError)
            return result.isRetryable == true
        }
    }

    func testServerErrorIsRetryable() {
        property(".serverError errors are retryable") <- forAllNoShrink(apiErrorGen(statusGen: serverStatusGen)) { apiError in
            let result = ErrorMapper.map(apiError)
            return result.isRetryable == true
        }
    }

    func testSessionExpiredIsNotRetryable() {
        property(".sessionExpired errors are not retryable") <- forAllNoShrink(apiErrorGen(statusGen: unauthorizedStatusGen)) { apiError in
            let result = ErrorMapper.map(apiError)
            return result.isRetryable == false
        }
    }

    func testValidationErrorIsNotRetryable() {
        property(".validationError errors are not retryable") <- forAllNoShrink(apiErrorGen(statusGen: validationStatusGen)) { apiError in
            let result = ErrorMapper.map(apiError)
            return result.isRetryable == false
        }
    }

    func testDecodingFailureIsNotRetryable() {
        // DecodingError is not easily generated arbitrarily, so we test with representative samples
        let decodingErrors: [Error] = [
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "test")),
            DecodingError.keyNotFound(AnyCodingKey(stringValue: "key")!, .init(codingPath: [], debugDescription: "missing")),
            DecodingError.typeMismatch(String.self, .init(codingPath: [], debugDescription: "type"))
        ]
        for error in decodingErrors {
            let result = ErrorMapper.map(error)
            XCTAssertEqual(category(of: result), .decodingFailure)
            XCTAssertFalse(result.isRetryable)
        }
    }

    func testUnknownErrorIsNotRetryable() {
        struct SomeError: Error {}
        let result = ErrorMapper.map(SomeError())
        XCTAssertEqual(category(of: result), .unknown)
        XCTAssertFalse(result.isRetryable)
    }
}

// MARK: - Helper CodingKey for DecodingError construction

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
