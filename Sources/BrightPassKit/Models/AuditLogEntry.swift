import Foundation

public struct AuditLogEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let action: String
    public let memberId: String
    public let timestamp: Date
    public let metadata: [String: String]?

    public init(id: String, action: String, memberId: String, timestamp: Date, metadata: [String: String]?) {
        self.id = id
        self.action = action
        self.memberId = memberId
        self.timestamp = timestamp
        self.metadata = metadata
    }
}
