import Foundation

public struct BreachCheckResult: Codable, Equatable, Sendable {
    public let breached: Bool
    public let breachCount: Int?

    public init(breached: Bool, breachCount: Int?) {
        self.breached = breached
        self.breachCount = breachCount
    }
}
