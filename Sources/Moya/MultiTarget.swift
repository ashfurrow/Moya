import Foundation

/// A `TargetType` used to enable `MoyaProvider` to process multiple `TargetType`s.
public enum MultiTarget: TargetType {
    /// The embedded `TargetType`.
    case target(any TargetType)

    /// Initializes a `MultiTarget`.
    public init(_ target: any TargetType) {
        self = MultiTarget.target(target)
    }

    /// The embedded target's base `URL`.
    public var path: String { target.path }

    /// The baseURL of the embedded target.
    public var baseURL: URL { target.baseURL }

    /// The HTTP method of the embedded target.
    public var method: Moya.Method { target.method }

    /// The sampleData of the embedded target.
    public var sampleData: Data { target.sampleData }

    /// The `Task` of the embedded target.
    public var task: Task { target.task }

    /// The `ValidationType` of the embedded target.
    public var validationType: ValidationType { target.validationType }

    /// The headers of the embedded target.
    public var headers: [String: String]? { target.headers }

    /// The embedded `TargetType`.
    public var target: any TargetType {
        switch self {
        case .target(let target): return target
        }
    }
}

extension MultiTarget: AccessTokenAuthorizable {
    public var authorizationType: AuthorizationType? {
        guard let authorizableTarget = target as? any AccessTokenAuthorizable else { return nil }
        return authorizableTarget.authorizationType
    }
}
