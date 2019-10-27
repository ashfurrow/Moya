import Foundation

/// A type representing possible errors Moya can throw.
public enum MoyaError: Swift.Error {

    /// Indicates a response failed to map to an image.
    case imageMapping(Response)

    /// Indicates a response failed to map to a JSON structure.
    case jsonMapping(Response)

    /// Indicates a response failed to map to a String.
    case stringMapping(Response)

    /// Indicates a response failed to map to a Decodable object.
    case objectMapping(Swift.Error, Response)

    /// Indicates that Encodable couldn't be encoded into Data
    case encodableMapping(String)

    /// Indicates a response failed with an invalid HTTP status code.
    case statusCode(Response)

    /// Indicates a response failed due to an underlying `Error`.
    case underlying(Swift.Error, Response?)

    /// Indicates that an `Endpoint` failed to map to a `URLRequest`.
    case requestMapping(String)
}

public extension MoyaError {
    /// Depending on error type, returns a `Response` object.
    var response: Moya.Response? {
        switch self {
        case let .imageMapping(response),
             let .jsonMapping(response),
             let .stringMapping(response),
             let .objectMapping(_, response),
             let .statusCode(response):
            return response

        case let .underlying (_, response):
            return response

        case .encodableMapping,
             .requestMapping:
            return nil
        }
    }

    /// Depending on error type, returns an underlying `Error`.
    internal var underlyingError: Swift.Error? {
        switch self {
        case let .objectMapping(error, _),
             let .underlying(error, _):
            return error

        case .imageMapping,
             .jsonMapping,
             .stringMapping,
             .encodableMapping,
             .statusCode,
             .requestMapping:
            return nil
        }
    }
}

// MARK: - Error Descriptions

extension MoyaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .imageMapping:
            return "Failed to map data to an Image."
        case .jsonMapping:
            return "Failed to map data to JSON."
        case .stringMapping:
            return "Failed to map data to a String."
        case .objectMapping:
            return "Failed to map data to a Decodable object."
        case let .encodableMapping(message):
            return message
        case .statusCode:
            return "Status code didn't fall within the given range."
        case .underlying(let error, _):
            return error.localizedDescription
        case .requestMapping:
            return "Failed to map Endpoint to a URLRequest."
        }
    }
}

// MARK: - Error User Info

extension MoyaError: CustomNSError {
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [:]
        userInfo[NSLocalizedDescriptionKey] = errorDescription
        userInfo[NSUnderlyingErrorKey] = underlyingError
        return userInfo
    }
}
