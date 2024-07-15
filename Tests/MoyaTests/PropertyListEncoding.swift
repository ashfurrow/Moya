import Alamofire
import Foundation

internal struct PropertyListEncoding: ParameterEncoding {

    // MARK: Properties
    /// Returns a default `PropertyListEncoding` instance.
    static var `default`: PropertyListEncoding { PropertyListEncoding() }

    /// Returns a `PropertyListEncoding` instance with xml formatting and default writing options.
    static var xml: PropertyListEncoding { PropertyListEncoding(format: .xml) }

    /// Returns a `PropertyListEncoding` instance with binary formatting and default writing options.
    static var binary: PropertyListEncoding { PropertyListEncoding(format: .binary) }

    /// The property list serialization format.
    let format: PropertyListSerialization.PropertyListFormat

    /// The options for writing the parameters as plist data.
    let options: PropertyListSerialization.WriteOptions

    // MARK: Initialization
    /// Creates a `PropertyListEncoding` instance using the specified format and options.
    ///
    /// - parameter format:  The property list serialization format.
    /// - parameter options: The options for writing the parameters as plist data.
    ///
    /// - returns: The new `PropertyListEncoding` instance.
    init(
        format: PropertyListSerialization.PropertyListFormat = .xml,
        options: PropertyListSerialization.WriteOptions = 0) {
        self.format = format
        self.options = options
    }

    // MARK: Encoding
    /// Creates a URL request by encoding parameters and applying them onto an existing request.
    ///
    /// - parameter urlRequest: The request to have parameters applied.
    /// - parameter parameters: The parameters to apply.
    ///
    /// - throws: An `Error` if the encoding process encounters an error.
    ///
    /// - returns: The encoded request.
    func encode(_ urlRequest: any URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()

        guard let parameters = parameters else { return urlRequest }

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: parameters,
                format: format,
                options: options
            )

            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/x-plist", forHTTPHeaderField: "Content-Type")
            }

            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncoderFailed(reason: AFError.ParameterEncoderFailureReason.encoderFailed(error: error))
        }

        return urlRequest
    }
}
