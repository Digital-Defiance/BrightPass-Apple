import Foundation

public struct VaultMetadata: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let ownerId: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let sharedWith: [String]?
    public let vcblBlockId: String?

    /// Backwards-compatible computed date from `updatedAt` or `createdAt`.
    public var lastModified: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let str = updatedAt, let d = formatter.date(from: str) { return d }
        if let str = createdAt, let d = formatter.date(from: str) { return d }
        return Date()
    }

    public init(id: String, name: String,
                ownerId: String? = nil, createdAt: String? = nil, updatedAt: String? = nil,
                sharedWith: [String]? = nil, vcblBlockId: String? = nil) {
        self.id = id
        self.name = name
        self.ownerId = ownerId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sharedWith = sharedWith
        self.vcblBlockId = vcblBlockId
    }
}
