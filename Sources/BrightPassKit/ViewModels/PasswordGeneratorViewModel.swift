import Foundation

/// Manages password generation options and API interaction.
/// The `length` property is clamped to 8–128 on every mutation.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class PasswordGeneratorViewModel {

    public var length: Int = 20 {
        didSet {
            let clamped = min(128, max(8, length))
            if length != clamped { length = clamped }
        }
    }
    public var includeUppercase: Bool = true
    public var includeLowercase: Bool = true
    public var includeDigits: Bool = true
    public var includeSpecial: Bool = true
    public var minUppercase: Int = 0
    public var minDigits: Int = 0
    public var minSpecial: Int = 0
    public var generatedPassword: String?
    public var isLoading: Bool = false
    public var error: AppError?

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Builds a `PasswordOptions` value from the current UI state.
    public var options: PasswordOptions {
        PasswordOptions(
            length: length,
            includeUppercase: includeUppercase,
            includeLowercase: includeLowercase,
            includeDigits: includeDigits,
            includeSpecial: includeSpecial,
            minUppercase: minUppercase,
            minDigits: minDigits,
            minSpecial: minSpecial
        )
    }

    /// Requests a new password from the API using the current options.
    public func generate() async {
        isLoading = true
        error = nil
        do {
            let result = try await apiClient.generatePassword(options: options)
            generatedPassword = result.password
        } catch {
            self.error = ErrorMapper.map(error)
        }
        isLoading = false
    }
}
