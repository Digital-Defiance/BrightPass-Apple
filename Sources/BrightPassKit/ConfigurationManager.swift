import Foundation
import Observation

/// Manages the API base URL for the BrightPass REST API,
/// supporting development (localhost) and production (brightchain.org) environments.
@available(macOS 14.0, iOS 17.0, *)
@Observable
public class ConfigurationManager {

    /// The base URL used by the API client for all network requests.
    public var baseURL: URL

    /// The target environment for API communication.
    public enum Environment {
        case development
        case production
    }

    /// Creates a configuration manager pointed at the given environment.
    /// - Parameter environment: The target environment. Defaults to `.production`.
    public init(environment: Environment = .production) {
        switch environment {
        case .development:
            baseURL = URL(string: "http://localhost:3000")!
        case .production:
            baseURL = URL(string: "https://brightchain.org")!
        }
    }
}
