import Foundation

public struct VaultEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: EntryType
    public let title: String
    public let fields: EntryFields
    public let tags: [String]
    public let isFavorite: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: String, type: EntryType, title: String, fields: EntryFields, tags: [String], isFavorite: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.type = type
        self.title = title
        self.fields = fields
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
