import Foundation

/// Closure to be executed when a request has completed.
public typealias Completion = (_ result: Result<Moya.Response, MoyaError>) -> Void

/// Closure to be executed when progress changes.
public typealias ProgressBlock = (_ progress: ProgressResponse) -> Void

/// A type representing the progress of a request.
public struct ProgressResponse {

    /// The optional response of the request.
    public let response: Response?

    /// An object that conveys ongoing progress for a given request.
    public let progressObject: Progress?

    /// Initializes a `ProgressResponse`.
    public init(progress: Progress? = nil, response: Response? = nil) {
        self.progressObject = progress
        self.response = response
    }

    /// The fraction of the overall work completed by the progress object.
    public var progress: Double {
        if completed {
            return 1.0
        } else if let progressObject = progressObject, progressObject.totalUnitCount > 0 {
            // if the Content-Length is specified we can rely on `fractionCompleted`
            return progressObject.fractionCompleted
        } else {
            // if the Content-Length is not specified, return progress 0.0 until it's completed
            return 0.0
        }
    }

    /// A Boolean value stating whether the request is completed.
    public var completed: Bool { response != nil }
}

/// A protocol representing a minimal interface for a MoyaProvider.
/// Used by the reactive provider extensions.
public protocol MoyaProviderType: AnyObject {

    associatedtype Target: TargetType

    /// Designated request-making method. Returns a `Cancellable` token to cancel the request later.
    func request(_ target: Target, callbackQueue: DispatchQueue?, progress: Moya.ProgressBlock?, completion: @escaping Moya.Completion) -> any Cancellable
}

/// Request provider class. Requests should be made through this class only.
open class MoyaProvider<Target: TargetType>: MoyaProviderType {

    /// Closure that defines the endpoints for the provider.
    public typealias EndpointClosure = (Target) -> Endpoint

    /// Closure that decides if and what request should be performed.
    public typealias RequestResultClosure = (Result<URLRequest, MoyaError>) -> Void

    /// Closure that resolves an `Endpoint` into a `RequestResult`.
    public typealias RequestClosure = (Endpoint, @escaping RequestResultClosure) -> Void

    /// Closure that decides if/how a request should be stubbed.
    public typealias StubClosure = (Target) -> Moya.StubBehavior

    /// A closure responsible for mapping a `TargetType` to an `EndPoint`.
    public let endpointClosure: EndpointClosure

    /// A closure deciding if and what request should be performed.
    public let requestClosure: RequestClosure

    /// A closure responsible for determining the stubbing behavior
    /// of a request for a given `TargetType`.
    public let stubClosure: StubClosure

    public let session: Session

    /// A list of plugins.
    /// e.g. for logging, network activity indicator or credentials.
    public let plugins: [any PluginType]

    public let trackInflights: Bool

    open var inflightRequests: [Endpoint: [Moya.Completion]] { internalInflightRequests }

    @Atomic
    var internalInflightRequests: [Endpoint: [Moya.Completion]] = [:]

    /// Propagated to Alamofire as callback queue. If nil - the Alamofire default (as of their API in 2017 - the main queue) will be used.
    let callbackQueue: DispatchQueue?

    let lock: NSRecursiveLock = NSRecursiveLock()

    /// Initializes a provider.
    public init(endpointClosure: @escaping EndpointClosure = MoyaProvider.defaultEndpointMapping,
                requestClosure: @escaping RequestClosure = MoyaProvider.defaultRequestMapping,
                stubClosure: @escaping StubClosure = MoyaProvider.neverStub,
                callbackQueue: DispatchQueue? = nil,
                session: Session = MoyaProvider<Target>.defaultAlamofireSession(),
                plugins: [any PluginType] = [],
                trackInflights: Bool = false) {

        self.endpointClosure = endpointClosure
        self.requestClosure = requestClosure
        self.stubClosure = stubClosure
        self.session = session
        self.plugins = plugins
        self.trackInflights = trackInflights
        self.callbackQueue = callbackQueue
    }

    /// Returns an `Endpoint` based on the token, method, and parameters by invoking the `endpointClosure`.
    open func endpoint(_ token: Target) -> Endpoint {
        endpointClosure(token)
    }

    /// Designated request-making method. Returns a `Cancellable` token to cancel the request later.
    @discardableResult
    open func request(_ target: Target,
                      callbackQueue: DispatchQueue? = .none,
                      progress: ProgressBlock? = .none,
                      completion: @escaping Completion) -> any Cancellable {

        let callbackQueue = callbackQueue ?? self.callbackQueue
        return requestNormal(target, callbackQueue: callbackQueue, progress: progress, completion: completion)
    }

    // swiftlint:disable function_parameter_count
    /// When overriding this method, call `notifyPluginsOfImpendingStub` to prepare your request
    /// and then use the returned `URLRequest` in the `createStubFunction` method.
    /// Note: this was previously in an extension, however it must be in the original class declaration to allow subclasses to override.
    @discardableResult
    open func stubRequest(_ target: Target, request: URLRequest, callbackQueue: DispatchQueue?, completion: @escaping Moya.Completion, endpoint: Endpoint, stubBehavior: Moya.StubBehavior) -> CancellableToken {
        let callbackQueue = callbackQueue ?? self.callbackQueue
        let cancellableToken = CancellableToken { }
        let preparedRequest = notifyPluginsOfImpendingStub(for: request, target: target)
        let plugins = self.plugins
        let stub: () -> Void = createStubFunction(cancellableToken, forTarget: target, withCompletion: completion, endpoint: endpoint, plugins: plugins, request: preparedRequest)
        switch stubBehavior {
        case .immediate:
            switch callbackQueue {
            case .none:
                stub()
            case .some(let callbackQueue):
                callbackQueue.async(execute: stub)
            }
        case .delayed(let delay):
            let killTimeOffset = Int64(CDouble(delay) * CDouble(NSEC_PER_SEC))
            let killTime = DispatchTime.now() + Double(killTimeOffset) / Double(NSEC_PER_SEC)
            (callbackQueue ?? DispatchQueue.main).asyncAfter(deadline: killTime) {
                stub()
            }
        case .never:
            fatalError("Method called to stub request when stubbing is disabled.")
        }

        return cancellableToken
    }
    // swiftlint:enable function_parameter_count
}

// MARK: Stubbing

/// Controls how stub responses are returned.
public enum StubBehavior {

    /// Do not stub.
    case never

    /// Return a response immediately.
    case immediate

    /// Return a response after a delay.
    case delayed(seconds: TimeInterval)
}

public extension MoyaProvider {

    // Swift won't let us put the StubBehavior enum inside the provider class, so we'll
    // at least add some class functions to allow easy access to common stubbing closures.

    /// Do not stub.
    final class func neverStub(_: Target) -> Moya.StubBehavior { .never }

    /// Return a response immediately.
    final class func immediatelyStub(_: Target) -> Moya.StubBehavior { .immediate }

    /// Return a response after a delay.
    final class func delayedStub(_ seconds: TimeInterval) -> (Target) -> Moya.StubBehavior {
        return { _ in .delayed(seconds: seconds) }
    }
}

/// A public function responsible for converting the result of a `URLRequest` to a Result<Moya.Response, MoyaError>.
public func convertResponseToResult(_ response: HTTPURLResponse?, request: URLRequest?, data: Data?, error: (any Swift.Error)?) ->
    Result<Moya.Response, MoyaError> {
        switch (response, data, error) {
        case let (.some(response), data, .none):
            let response = Moya.Response(statusCode: response.statusCode, data: data ?? Data(), request: request, response: response)
            return .success(response)
        case let (.some(response), _, .some(error)):
            let response = Moya.Response(statusCode: response.statusCode, data: data ?? Data(), request: request, response: response)
            let error = MoyaError.underlying(error, response)
            return .failure(error)
        case let (_, _, .some(error)):
            let error = MoyaError.underlying(error, nil)
            return .failure(error)
        default:
            let error = MoyaError.underlying(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil), nil)
            return .failure(error)
        }
}
