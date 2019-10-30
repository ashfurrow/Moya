import Foundation
import Moya

extension Task {
    typealias TaskParameters = (Encodable, ParameterEncoder)

    func allParameters() throws -> [TaskParameters] {
        switch self {
        case let .request(bodyParams, queryParams),
             let .upload(_, bodyParams, queryParams),
             let .download(_, bodyParams, queryParams):
            return try [bodyParams?.taskParameters(), queryParams?.taskParameters()].compactMap { $0 }
        }
    }
}

// MARK: - TaskParametersProvider
private protocol TaskParametersProvider {
    func taskParameters() throws -> Task.TaskParameters
}

extension Task.BodyParams: TaskParametersProvider {
    func taskParameters() throws -> Task.TaskParameters {
        switch self {
        case let .urlEncoded(encodable, encoder):
            return (encodable, URLEncodedFormParameterEncoder(encoder: encoder, destination: .httpBody))

        case let .custom(encodable, encoder):
            guard !(encoder is JSONParameterEncoder) else {
                throw MoyaError.encodableMapping("A JSONParameterEncoder can not be used in Task.BodyParams.custom(). Use Task.BodyParams.json() instead.")
            }
            guard !(encoder is URLEncodedFormParameterEncoder) else {
                throw MoyaError.encodableMapping("An URLEncodedFormParameterEncoder can not be used in Task.BodyParams.custom(). Use Task.BodyParams.urlEncoded() instead.")
            }
            return (encodable, encoder)

        case let .json(encodable, encoder):
            return (encodable, JSONParameterEncoder(encoder: encoder))

        case let .raw(encodable):
            return (encodable, RawDataParameterEncoder())
        }
    }
}

extension Task.QueryParams: TaskParametersProvider {
    func taskParameters() throws -> Task.TaskParameters {
        switch self {
        case let .query(encodable, encoder):
            return (encodable, URLEncodedFormParameterEncoder(encoder: encoder, destination: .queryString))
        }
    }
}
