import Foundation

/// Logs network activity (outgoing requests and incoming responses).
public final class NetworkLoggerPlugin {

    public var configuration: Configuration

    /// Initializes a NetworkLoggerPlugin.
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
}

// MARK: - PluginType
extension NetworkLoggerPlugin: PluginType {
    public func willSend(_ request: any RequestType, target: any TargetType) {
        logNetworkRequest(request, target: target) { [weak self] output in
            self?.configuration.output(target, output)
        }
    }

    public func didReceive(_ result: Result<Moya.Response, MoyaError>, target: any TargetType) {
        switch result {
        case .success(let response):
            configuration.output(target, logNetworkResponse(response, target: target, isFromError: false))
        case let .failure(error):
            configuration.output(target, logNetworkError(error, target: target))
        }
    }
}

// MARK: - Logging
private extension NetworkLoggerPlugin {

    func logNetworkRequest(_ request: any RequestType, target: any TargetType, completion: @escaping ([String]) -> Void) {
        //cURL formatting
        if configuration.logOptions.contains(.formatRequestAscURL) {
            _ = request.cURLDescription { [weak self] output in
                guard let self = self else { return }

                completion([self.configuration.formatter.entry("Request", output, target)])
            }
            return
        }

        //Request presence check
        guard let httpRequest = request.request else {
            completion([configuration.formatter.entry("Request", "(invalid request)", target)])
            return
        }

        // Adding log entries for each given log option
        var output = [String]()

        output.append(configuration.formatter.entry("Request", httpRequest.description, target))

        if configuration.logOptions.contains(.requestHeaders) {
            var allHeaders = request.sessionHeaders
            if let httpRequestHeaders = httpRequest.allHTTPHeaderFields {
                allHeaders.merge(httpRequestHeaders) { $1 }
            }
            output.append(configuration.formatter.entry("Request Headers", allHeaders.description, target))
        }

        if configuration.logOptions.contains(.requestBody) {
            if let bodyStream = httpRequest.httpBodyStream {
                output.append(configuration.formatter.entry("Request Body Stream", bodyStream.description, target))
            }

            if let body = httpRequest.httpBody {
                let stringOutput = configuration.formatter.requestData(body)
                output.append(configuration.formatter.entry("Request Body", stringOutput, target))
            }
        }

        if configuration.logOptions.contains(.requestMethod),
            let httpMethod = httpRequest.httpMethod {
            output.append(configuration.formatter.entry("HTTP Request Method", httpMethod, target))
        }

        completion(output)
    }

    func logNetworkResponse(_ response: Response, target: any TargetType, isFromError: Bool) -> [String] {
        // Adding log entries for each given log option
        var output = [String]()

        //Response presence check
        if let httpResponse = response.response {
            output.append(configuration.formatter.entry("Response", httpResponse.description, target))
        } else {
            output.append(configuration.formatter.entry("Response", "Received empty network response for \(target).", target))
        }

        if (isFromError && configuration.logOptions.contains(.errorResponseBody))
            || configuration.logOptions.contains(.successResponseBody) {

            let stringOutput = configuration.formatter.responseData(response.data)
            output.append(configuration.formatter.entry("Response Body", stringOutput, target))
        }

        return output
    }

    func logNetworkError(_ error: MoyaError, target: any TargetType) -> [String] {
        //Some errors will still have a response, like errors due to Alamofire's HTTP code validation.
        if let moyaResponse = error.response {
            return logNetworkResponse(moyaResponse, target: target, isFromError: true)
        }

        //Errors without an HTTPURLResponse are those due to connectivity, time-out and such.
        return [configuration.formatter.entry("Error", "Error calling \(target) : \(error)", target)]
    }
}

// MARK: - Configuration
public extension NetworkLoggerPlugin {
    struct Configuration {

        // MARK: - Typealiases
        // swiftlint:disable nesting
        public typealias OutputType = (_ target: any TargetType, _ items: [String]) -> Void
        // swiftlint:enable nesting

        // MARK: - Properties

        public var formatter: Formatter
        public var output: OutputType
        public var logOptions: LogOptions

        /// The designated way to instantiate a Configuration.
        ///
        /// - Parameters:
        ///   - formatter: An object holding all formatter closures available for customization.
        ///   - output: A closure responsible for writing the given log entries into your log system.
        ///                    The default value writes entries to the debug console.
        ///   - logOptions: A set of options you can use to customize which request component is logged.
        public init(formatter: Formatter = Formatter(),
                    output: @escaping OutputType = defaultOutput,
                    logOptions: LogOptions = .default) {
            self.formatter = formatter
            self.output = output
            self.logOptions = logOptions
        }

        // MARK: - Defaults

        public static func defaultOutput(target: any TargetType, items: [String]) {
            for item in items {
                print(item, separator: ",", terminator: "\n")
            }
        }
    }
}

public extension NetworkLoggerPlugin.Configuration {
    struct LogOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// The request's method will be logged.
        public static let requestMethod: LogOptions = LogOptions(rawValue: 1 << 0)
        /// The request's body will be logged.
        public static let requestBody: LogOptions = LogOptions(rawValue: 1 << 1)
        /// The request's headers will be logged.
        public static let requestHeaders: LogOptions = LogOptions(rawValue: 1 << 2)
        /// The request will be logged in the cURL format.
        ///
        /// If this option is used, the following components will be logged regardless of their respective options being set:
        /// - request's method
        /// - request's headers
        /// - request's body.
        public static let formatRequestAscURL: LogOptions = LogOptions(rawValue: 1 << 3)
        /// The body of a response that is a success will be logged.
        public static let successResponseBody: LogOptions = LogOptions(rawValue: 1 << 4)
        /// The body of a response that is an error will be logged.
        public static let errorResponseBody: LogOptions = LogOptions(rawValue: 1 << 5)

        //Aggregate options
        /// Only basic components will be logged.
        public static let `default`: LogOptions = [requestMethod, requestHeaders]
        /// All components will be logged.
        public static let verbose: LogOptions = [requestMethod, requestHeaders, requestBody,
                                                 successResponseBody, errorResponseBody]
    }
}

public extension NetworkLoggerPlugin.Configuration {
    struct Formatter {

        // MARK: Typealiases
        // swiftlint:disable nesting
        public typealias DataFormatterType = (Data) -> (String)
        public typealias EntryFormatterType = (_ identifier: String, _ message: String, _ target: any TargetType) -> String
        // swiftlint:enable nesting

        // MARK: Properties

        public var entry: EntryFormatterType
        public var requestData: DataFormatterType
        public var responseData: DataFormatterType

        /// The designated way to instantiate a Formatter.
        ///
        /// - Parameters:
        ///   - entry: The closure formatting a message into a new log entry.
        ///   - requestData: The closure converting HTTP request's body into a String.
        ///     The default value assumes the body's data is an utf8 String.
        ///   - responseData: The closure converting HTTP response's body into a String.
        ///     The default value assumes the body's data is an utf8 String.
        public init(entry: @escaping EntryFormatterType = defaultEntryFormatter,
                    requestData: @escaping DataFormatterType = defaultDataFormatter,
                    responseData: @escaping DataFormatterType = defaultDataFormatter) {
            self.entry = entry
            self.requestData = requestData
            self.responseData = responseData
        }

        // MARK: Defaults

        public static func defaultDataFormatter(_ data: Data) -> String {
            return String(data: data, encoding: .utf8) ?? "## Cannot map data to String ##"
        }

        public static func defaultEntryFormatter(identifier: String, message: String, target: any TargetType) -> String {
            let date = defaultEntryDateFormatter.string(from: Date())
            return "Moya_Logger: [\(date)] \(identifier): \(message)"
        }

        static var defaultEntryDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .short
            return formatter
        }()
    }
}

public extension NetworkLoggerPlugin {
    /// Returns the default logger plugin
    class var `default`: NetworkLoggerPlugin {
        return NetworkLoggerPlugin(configuration: Configuration(logOptions: .default))
    }

    /// Returns the default verbose logger plugin
    class var verbose: NetworkLoggerPlugin {
        return NetworkLoggerPlugin(configuration: Configuration(logOptions: .verbose))
    }
}
