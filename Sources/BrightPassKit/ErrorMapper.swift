import Foundation

/// Maps raw errors from URLSession, API responses, and JSON decoding
/// into structured `AppError` values for consistent UI presentation.
public struct ErrorMapper {

    /// Classifies an arbitrary error into the appropriate `AppError` case.
    public static func map(_ error: Error) -> AppError {
        switch error {
        case let urlError as URLError:
            return mapNetworkError(urlError)
        case let apiError as APIError:
            return mapAPIError(apiError)
        case is DecodingError:
            return .decodingFailure(detail: error.localizedDescription)
        default:
            return .unknown(underlying: error)
        }
    }

    private static func mapNetworkError(_ error: URLError) -> AppError {
        switch error.code {
        case .timedOut, .notConnectedToInternet, .networkConnectionLost:
            return .networkUnavailable(message: "Network is unavailable. Check your connection and try again.")
        default:
            return .networkUnavailable(message: "A network error occurred. Please try again.")
        }
    }

    private static func mapAPIError(_ error: APIError) -> AppError {
        switch error.status {
        case 401:
            return .sessionExpired
        case 400..<500:
            return .validationError(messages: error.details ?? [error.message])
        case 500..<600:
            return .serverError(message: "A server error occurred. Please try again later.")
        default:
            return .unknown(underlying: error)
        }
    }
}
