import Foundation

/// Represents an HTTP task.
public enum Task<JSONEncondable: Encodable> {

    /// A request with no additional data.
    case requestPlain

    /// A requests body set with data.
    case requestData(Data)

    /// A request body set with data.
    case requestJSONEncodable(JSONEncondable)

    /// A requests body set with encoded parameters.
    case requestParameters(parameters: [String: Any], encoding: ParameterEncoding)

    /// A requests body set with data, combined with url parameters.
    case requestCompositeData(bodyData: Data, urlParameters: [String: Any])

    /// A requests body set with encoded parameters combined with url parameters.
    case requestCompositeParameters(bodyParameters: [String: Any], bodyEncoding: ParameterEncoding, urlParameters: [String: Any])

    /// A file upload task.
    case uploadFile(URL)

    /// A "multipart/form-data" upload task.
    case uploadMultipart([MultipartFormData])

    /// A "multipart/form-data" upload task  combined with url parameters.
    case uploadCompositeMultipart([MultipartFormData], urlParameters: [String: Any])

    /// A file download task to a destination.
    case downloadDestination(DownloadDestination)

    /// A file download task to a destination with extra parameters using the given encoding.
    case downloadParameters(parameters: [String: Any], encoding: ParameterEncoding, destination: DownloadDestination)

    func encodableRequest<T: Encodable>() -> T? {
        switch self {
        case .requestJSONEncodable(let encodable):
            return encodable as? T
        default:
            return nil
        }
    }
}
