import Foundation

/// Network activity change notification type.
public enum NetworkActivityChangeType {
    case began, ended
}

/// Notify a request's network activity changes (request begins or ends).
public final class NetworkActivityPlugin: PluginType {

    public typealias NetworkActivityClosure = (_ change: NetworkActivityChangeType, _ target: any TargetType) -> Void
    let networkActivityClosure: NetworkActivityClosure

    /// Initializes a NetworkActivityPlugin.
    public init(networkActivityClosure: @escaping NetworkActivityClosure) {
        self.networkActivityClosure = networkActivityClosure
    }

    // MARK: Plugin

    /// Called by the provider as soon as the request is about to start
    public func willSend(_ request: any RequestType, target: any TargetType) {
        networkActivityClosure(.began, target)
    }

    /// Called by the provider as soon as a response arrives, even if the request is canceled.
    public func didReceive(_ result: Result<Moya.Response, MoyaError>, target: any TargetType) {
        networkActivityClosure(.ended, target)
    }
}
