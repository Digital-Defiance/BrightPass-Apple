import Foundation

/// Unified application error type that maps network, API, and decoding errors
/// into user-facing categories with retryability information.
public enum AppError: Error, Equatable {
    case networkUnavailable(message: String)
    case sessionExpired
    case validationError(messages: [String])
    case serverError(message: String)
    case decodingFailure(detail: String)
    case unknown(underlying: Error)

    /// Whether the error represents a transient condition that may succeed on retry.
    public var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .serverError: return true
        case .sessionExpired, .validationError, .decodingFailure, .unknown: return false
        }
    }

    /// A human-readable message suitable for display in the UI.
    public var userMessage: String {
        switch self {
        case .networkUnavailable(let msg): return msg
        case .sessionExpired: return "Your session has expired. Please log in again."
        case .validationError(let msgs): return msgs.joined(separator: "\n")
        case .serverError(let msg): return msg
        case .decodingFailure(let detail): return "Failed to process server response: \(detail)"
        case .unknown: return "An unexpected error occurred."
        }
    }

    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.networkUnavailable(let a), .networkUnavailable(let b)): return a == b
        case (.sessionExpired, .sessionExpired): return true
        case (.validationError(let a), .validationError(let b)): return a == b
        case (.serverError(let a), .serverError(let b)): return a == b
        case (.decodingFailure(let a), .decodingFailure(let b)): return a == b
        default: return false
        }
    }
}
