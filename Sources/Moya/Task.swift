import Foundation

/// Represents an HTTP task.
public enum Task {

    /// A request with no additional data.
    case requestPlain

    /// A requests body set with data.
    case requestData(Data)

    /// A request body set with `Encodable` type
    case requestJSONEncodable(any Encodable)

    /// A request body set with `Encodable` type and custom encoder
    case requestCustomJSONEncodable(any Encodable, encoder: JSONEncoder)

    /// A requests body set with encoded parameters.
    case requestParameters(parameters: [String: Any], encoding: any ParameterEncoding)

    /// A requests body set with data, combined with url parameters.
    case requestCompositeData(bodyData: Data, urlParameters: [String: Any])

    /// A requests body set with encoded parameters combined with url parameters.
    case requestCompositeParameters(bodyParameters: [String: Any], bodyEncoding: any ParameterEncoding, urlParameters: [String: Any])

    /// A file upload task.
    case uploadFile(URL)

    /// A "multipart/form-data" upload task.
    case uploadMultipartFormData(MultipartFormData)

    /// A "multipart/form-data" upload task.
    @available(*, deprecated, message: "use `uploadMultipartFormData(MultipartFormData)` instead")
    case uploadMultipart([MultipartFormBodyPart])

    /// A "multipart/form-data" upload task  combined with url parameters.
    case uploadCompositeMultipartFormData(MultipartFormData, urlParameters: [String: Any])

    /// A "multipart/form-data" upload task  combined with url parameters.
    @available(*, deprecated, message: "use `uploadCompositeMultipartFormData(MultipartFormData)` instead")
    case uploadCompositeMultipart([MultipartFormBodyPart], urlParameters: [String: Any])

    /// A file download task to a destination.
    case downloadDestination(DownloadDestination)

    /// A file download task to a destination with extra parameters using the given encoding.
    case downloadParameters(parameters: [String: Any], encoding: any ParameterEncoding, destination: DownloadDestination)
}
