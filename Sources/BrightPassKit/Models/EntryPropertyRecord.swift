import Foundation

public struct EntryPropertyRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let type: EntryType
    public let tags: [String]
    public let url: String?
    public let isFavorite: Bool
    public let createdAt: Date?
    public let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case type = "entryType"
        case tags
        case url = "siteUrl"
        case isFavorite = "favorite"
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Server may not include id in property records; generate a stable fallback
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.title = try container.decode(String.self, forKey: .title)
        self.type = try container.decode(EntryType.self, forKey: .type)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    public init(id: String, title: String, type: EntryType, tags: [String], url: String?, isFavorite: Bool, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.type = type
        self.tags = tags
        self.url = url
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
