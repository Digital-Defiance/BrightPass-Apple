import Foundation

public struct ImportResult: Codable, Equatable, Sendable {
    public let importedCount: Int
    public let errors: [String]

    public init(importedCount: Int, errors: [String]) {
        self.importedCount = importedCount
        self.errors = errors
    }
}

public enum ImportSource: String, Codable, Equatable, CaseIterable, Sendable {
    case onePassword1PUX
    case onePasswordCSV
    case lastPassCSV
    case bitwardenJSON
    case bitwardenCSV
    case chromeCSV
    case firefoxCSV
    case keepassXML
    case dashlaneJSON
}
