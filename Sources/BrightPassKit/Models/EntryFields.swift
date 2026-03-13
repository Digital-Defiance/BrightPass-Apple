import Foundation

public enum EntryFields: Codable, Equatable, Sendable {
    case login(LoginFields)
    case secureNote(SecureNoteFields)
    case creditCard(CreditCardFields)
    case identityDocument(IdentityDocumentFields)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum FieldType: String, Codable {
        case login
        case secureNote
        case creditCard
        case identityDocument
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FieldType.self, forKey: .type)
        let singleContainer = try decoder.singleValueContainer()
        switch type {
        case .login:
            self = .login(try singleContainer.decode(LoginFields.self))
        case .secureNote:
            self = .secureNote(try singleContainer.decode(SecureNoteFields.self))
        case .creditCard:
            self = .creditCard(try singleContainer.decode(CreditCardFields.self))
        case .identityDocument:
            self = .identityDocument(try singleContainer.decode(IdentityDocumentFields.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .login(let fields):
            try container.encode(FieldType.login, forKey: .type)
            try fields.encode(to: encoder)
        case .secureNote(let fields):
            try container.encode(FieldType.secureNote, forKey: .type)
            try fields.encode(to: encoder)
        case .creditCard(let fields):
            try container.encode(FieldType.creditCard, forKey: .type)
            try fields.encode(to: encoder)
        case .identityDocument(let fields):
            try container.encode(FieldType.identityDocument, forKey: .type)
            try fields.encode(to: encoder)
        }
    }
}

public struct LoginFields: Codable, Equatable, Sendable {
    public let siteURL: String
    public let username: String
    public let password: String
    public let totpSecret: String?

    public init(siteURL: String, username: String, password: String, totpSecret: String?) {
        self.siteURL = siteURL
        self.username = username
        self.password = password
        self.totpSecret = totpSecret
    }
}

public struct SecureNoteFields: Codable, Equatable, Sendable {
    public let content: String

    public init(content: String) {
        self.content = content
    }
}

public struct CreditCardFields: Codable, Equatable, Sendable {
    public let cardholderName: String
    public let cardNumber: String
    public let expirationDate: String
    public let cvv: String

    public init(cardholderName: String, cardNumber: String, expirationDate: String, cvv: String) {
        self.cardholderName = cardholderName
        self.cardNumber = cardNumber
        self.expirationDate = expirationDate
        self.cvv = cvv
    }
}

public struct IdentityDocumentFields: Codable, Equatable, Sendable {
    public let name: String
    public let email: String
    public let phone: String
    public let address: String
    public let customFields: [String: String]

    public init(name: String, email: String, phone: String, address: String, customFields: [String: String]) {
        self.name = name
        self.email = email
        self.phone = phone
        self.address = address
        self.customFields = customFields
    }
}
