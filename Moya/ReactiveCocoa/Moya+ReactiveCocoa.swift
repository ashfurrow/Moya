import Foundation
import ReactiveCocoa
import Result

/// Subclass of MoyaProvider that returns RACSignal instances when requests are made. Much better than using completion closures.
public class ReactiveCocoaMoyaProvider<T where T: MoyaTarget>: MoyaProvider<T> {
    /// Current requests that have not completed or errored yet.
    /// Note: Do not access this directly. It is public only for unit-testing purposes (sigh).
    public var inflightRequests = Dictionary<Endpoint<T>, SignalProducer<MoyaResponse, NSError>>()

    /// Initializes a reactive provider.
    override public init(endpointClosure: MoyaEndpointsClosure = MoyaProvider.DefaultEndpointMapping, endpointResolver: MoyaEndpointResolution = MoyaProvider.DefaultEnpointResolution, stubBehavior: MoyaStubbedBehavior = MoyaProvider.NoStubbingBehavior, networkActivityClosure: Moya.NetworkActivityClosure? = nil) {
        super.init(endpointClosure: endpointClosure, endpointResolver: endpointResolver, stubBehavior: stubBehavior, networkActivityClosure: networkActivityClosure)
    }
    
    public func request(token: T) -> SignalProducer<MoyaResponse, NSError> {
        let endpoint = self.endpoint(token)
        
        if let existingSignal = inflightRequests[endpoint] {
            return existingSignal
        }
        
        let producer: SignalProducer<MoyaResponse, NSError> = SignalProducer { [weak self] sink, disposable in
            let cancellableToken = self?.request(token) { data, statusCode, response, error in
                if let error = error {
                    if let statusCode = statusCode {
                        sendError(sink, NSError(domain: error.domain, code: statusCode, userInfo: error.userInfo))
                    } else {
                        sendError(sink, error)
                    }
                } else {
                    if let data = data {
                        sendNext(sink, MoyaResponse(statusCode: statusCode!, data: data, response: response))
                    }
                    
                    sendCompleted(sink)
                }
            }
            
            disposable.addDisposable {
                if let weakSelf = self {
                    objc_sync_enter(weakSelf)
                    weakSelf.inflightRequests[endpoint] = nil
                    objc_sync_exit(weakSelf)
                    
                    cancellableToken?.cancel()
                }
            }
        }
    
        objc_sync_enter(self)
        inflightRequests[endpoint] = producer
        objc_sync_exit(self)
        
        return producer
    }
}

public extension ReactiveCocoaMoyaProvider {
    public func requestJSON(token: T) -> SignalProducer<AnyObject, NSError> {
        return request(token) |> mapJSON()
    }
    
    public func requestImage(token: T) -> SignalProducer<UIImage, NSError> {
        return request(token) |> mapImage()
    }

    public func requestString(token: T) -> SignalProducer<String, NSError> {
        return request(token) |> mapString()
    }
}

public let ReactiveMoyaErrorDomain = "Moya"

public enum ReactiveMoyaError {
    public enum ErrorCode: Int {
        case ResponseMapping = -1
        case ImageMapping
        case JSONMapping
        case StringMapping
        case StatusCode
        case Data
    }
    
    case ResponseMapping(AnyObject)
    case ImageMapping(AnyObject)
    case JSONMapping(AnyObject)
    case StringMapping(AnyObject)
    case StatusCode(AnyObject)
    case Data(AnyObject)
    
    func errorCode() -> Int {
        switch self {
        case ResponseMapping:
            return ErrorCode.ResponseMapping.rawValue
        case ImageMapping:
            return ErrorCode.ImageMapping.rawValue
        case JSONMapping:
            return ErrorCode.JSONMapping.rawValue
        case StringMapping:
            return ErrorCode.StringMapping.rawValue
        case StatusCode:
            return ErrorCode.StatusCode.rawValue
        case Data:
            return ErrorCode.Data.rawValue
        }
    }
    
    func userInfo() -> [NSObject: AnyObject] {
        switch self {
        case .ResponseMapping(let object):
            return ["data": object]
        case .ImageMapping(let object):
            return ["data": object]
        case .JSONMapping(let object):
            return ["data": object]
        case .StringMapping(let object):
            return ["data": object]
        case .StatusCode(let object):
            return ["data": object]
        case .Data(let object):
            return ["data": object]
        }
    }
    
    func toError() -> NSError {
        return NSError(domain: ReactiveMoyaErrorDomain, code: errorCode(), userInfo: userInfo())
    }
}

public func filterStatusCode(range: ClosedInterval<Int>) -> Signal<MoyaResponse, NSError> -> Signal<MoyaResponse, NSError>  {
    return attemptMap { (response: MoyaResponse) in
        if range.contains(response.statusCode) {
            return Result.Success(response)
        } else {
            return Result.Failure(ReactiveMoyaError.StatusCode(response).toError())
        }
    }
}

public func filterStatusCode(code: Int) -> Signal<MoyaResponse, NSError> -> Signal<MoyaResponse, NSError> {
    return filterStatusCode(code...code)
}

public func filterSuccessfulStatusCodes() -> Signal<MoyaResponse, NSError> -> Signal<MoyaResponse, NSError> {
    return filterStatusCode(200...299)
}

public func filterSuccessfulAndRedirectCodes() -> Signal<MoyaResponse, NSError> -> Signal<MoyaResponse, NSError> {
    return filterStatusCode(200...399)
}

public func mapImage() -> Signal<MoyaResponse, NSError> -> Signal<UIImage, NSError> {
    return attemptMap { (response: MoyaResponse) -> Result<UIImage, NSError> in
        if let image = UIImage(data: response.data) {
            return Result.Success(image)
        } else {
            return Result.Failure(ReactiveMoyaError.ImageMapping(response).toError())
        }
    }
}

public func mapJSON() -> Signal<MoyaResponse, NSError> -> Signal<AnyObject, NSError> {
    return attemptMap { (response: MoyaResponse) -> Result<AnyObject, NSError> in
        do {
            let json: AnyObject = try NSJSONSerialization.JSONObjectWithData(response.data, options: NSJSONReadingOptions.AllowFragments)
            return Result.Success(json)
        } catch {
            return Result.Failure(ReactiveMoyaError.JSONMapping(response).toError())
        }
    }
}

public func mapString() -> Signal<MoyaResponse, NSError> -> Signal<String, NSError> {
    return attemptMap { (response: MoyaResponse) -> Result<String, NSError> in
        if let string: String =  NSString(data: response.data, encoding: NSUTF8StringEncoding) as? String {
            return Result.Success(string)
        } else {
            return Result.Failure(ReactiveMoyaError.StringMapping(response).toError())
        }
    }
}
