import Foundation

public struct EmergencyAccessConfig: Codable, Equatable, Sendable {
    public let totalShares: Int
    public let threshold: Int
    public let trustees: [String]

    public init(totalShares: Int, threshold: Int, trustees: [String]) {
        self.totalShares = totalShares
        self.threshold = threshold
        self.trustees = trustees
    }
}
