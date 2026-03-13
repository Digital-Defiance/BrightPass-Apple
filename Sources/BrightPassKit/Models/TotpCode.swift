import Foundation

public struct TotpCode: Codable, Equatable, Sendable {
    public let code: String
    public let remainingSeconds: Int
    public let period: Int

    public init(code: String, remainingSeconds: Int, period: Int) {
        self.code = code
        self.remainingSeconds = remainingSeconds
        self.period = period
    }
}
