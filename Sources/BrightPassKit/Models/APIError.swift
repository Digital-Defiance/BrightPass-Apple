import Foundation

public struct APIError: Codable, Equatable, Error, Sendable {
    public let status: Int
    public let code: String
    public let message: String
    public let details: [String]?

    public init(status: Int, code: String, message: String, details: [String]?) {
        self.status = status
        self.code = code
        self.message = message
        self.details = details
    }
}
