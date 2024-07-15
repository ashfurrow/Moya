import Foundation

// MARK: - AccessTokenAuthorizable

/// A protocol for controlling the behavior of `AccessTokenPlugin`.
public protocol AccessTokenAuthorizable {

    /// Represents the authorization header to use for requests.
    var authorizationType: AuthorizationType? { get }
}

// MARK: - AuthorizationType

/// An enum representing the header to use with an `AccessTokenPlugin`
public enum AuthorizationType {

    /// The `"Basic"` header.
    case basic

    /// The `"Bearer"` header.
    case bearer

    /// Custom header implementation.
    case custom(String)

    public var value: String {
        switch self {
        case .basic: return "Basic"
        case .bearer: return "Bearer"
        case .custom(let customValue): return customValue
        }
    }
}

extension AuthorizationType: Equatable {
    public static func == (lhs: AuthorizationType, rhs: AuthorizationType) -> Bool {
        switch (lhs, rhs) {
        case (.basic, .basic),
             (.bearer, .bearer):
            return true

        case let (.custom(value1), .custom(value2)):
            return value1 == value2

        default:
            return false
        }
    }
}

// MARK: - AccessTokenPlugin

/**
 A plugin for adding basic or bearer-type authorization headers to requests. Example:

 ```
 Authorization: Basic <token>
 Authorization: Bearer <token>
 Authorization: <Custom> <token>
 ```

 */
public struct AccessTokenPlugin: PluginType {

    public typealias TokenClosure = (any TargetType) -> String

    /// A closure returning the access token to be applied in the header.
    public let tokenClosure: TokenClosure

    /**
     Initialize a new `AccessTokenPlugin`.

     - parameters:
     - tokenClosure: A closure returning the token to be applied in the pattern `Authorization: <AuthorizationType> <token>`
     */
    public init(tokenClosure: @escaping TokenClosure) {
        self.tokenClosure = tokenClosure
    }

    /**
     Prepare a request by adding an authorization header if necessary.

     - parameters:
     - request: The request to modify.
     - target: The target of the request.
     - returns: The modified `URLRequest`.
     */
    public func prepare(_ request: URLRequest, target: any TargetType) -> URLRequest {

        guard let authorizable = target as? any AccessTokenAuthorizable,
            let authorizationType = authorizable.authorizationType
            else { return request }

        var request = request
        let realTarget = (target as? MultiTarget)?.target ?? target
        let authValue = authorizationType.value + " " + tokenClosure(realTarget)
        request.addValue(authValue, forHTTPHeaderField: "Authorization")

        return request
    }
}
