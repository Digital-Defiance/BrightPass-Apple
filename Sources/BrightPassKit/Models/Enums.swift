import Foundation

public enum PasswordStrengthLevel: String, Codable, Equatable, CaseIterable, Sendable {
    case weak
    case fair
    case good
    case strong
}

public enum SortOption: String, Codable, Equatable, CaseIterable, Sendable {
    case nameAscending
    case nameDescending
    case dateModifiedNewest
    case dateModifiedOldest
    case dateCreatedNewest
    case dateCreatedOldest
    case entryType
}

public enum ExportFormat: String, Codable, Equatable, CaseIterable, Sendable {
    case csv
    case json
}

public enum AppearanceMode: String, Codable, Equatable, CaseIterable, Sendable {
    case system
    case light
    case dark
}
