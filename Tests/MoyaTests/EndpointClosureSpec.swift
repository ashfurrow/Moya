import Foundation
import Nimble
import Quick
import Alamofire
@testable import Moya

final class EndpointClosureSpec: QuickSpec {

    override func spec() {
        var provider: MoyaProvider<HTTPBin>!
        var session: SessionMock!

        beforeEach {
            session = SessionMock()
            let endpointClosure: MoyaProvider<HTTPBin>.EndpointClosure = { target in
                let task: Task

                switch target.task {
                case let .uploadMultipartFormData(multipartFormData):
                    let additionalBodyPart = Moya.MultipartFormBodyPart(provider: .data("test2".data(using: .utf8)!), name: "test2")
                    let newMultipartFormData = MultipartFormData(parts: multipartFormData.parts + CollectionOfOne(additionalBodyPart))
                    task = .uploadMultipartFormData(newMultipartFormData)
                case let .uploadMultipart(multipartFormBodyParts):
                    let additionalBodyPart = Moya.MultipartFormBodyPart(provider: .data("test2".data(using: .utf8)!), name: "test2")
                    let newMultipartFormData = multipartFormBodyParts + CollectionOfOne(additionalBodyPart)
                    task = .uploadMultipart(newMultipartFormData)
                default:
                    task = target.task
                }

                return Endpoint(url: URL(target: target).absoluteString, sampleResponseClosure: {.networkResponse(200, target.sampleData)}, method: target.method, task: task, httpHeaderFields: target.headers)
            }
            provider = MoyaProvider<HTTPBin>(endpointClosure: endpointClosure, session: session)
        }

        it("appends additional multipart body in endpointClosure") {
            let multipartData1 = Moya.MultipartFormBodyPart(provider: .data("test1".data(using: .utf8)!), name: "test1")
            let multipartData2 = Moya.MultipartFormBodyPart(provider: .data("test2".data(using: .utf8)!), name: "test2")

            let providedMultipartData: Moya.MultipartFormData = [multipartData1]
            let sentMultipartData: Moya.MultipartFormData = [multipartData1, multipartData2]

            _ = provider.request(HTTPBin.uploadMultipartFormData(providedMultipartData, nil)) { _ in }
            let stringData1 = session.uploadMultipartString!

            let requestMultipartFormData = RequestMultipartFormData(fileManager: sentMultipartData.fileManager, boundary: sentMultipartData.boundary)
            requestMultipartFormData.applyMoyaMultipartFormData(sentMultipartData)
            let stringData2 = String(decoding: try! requestMultipartFormData.encode(), as: UTF8.self)

            let formData1 = "data; name=\"test1\"\r\n\r\ntest1\r\n"
            let formData2 = "data; name=\"test2\"\r\n\r\ntest2\r\n"

            let splitString1 = stringData1.split(separator: "-").map { String($0) }
            let splitString2 = stringData2.split(separator: "-").map { String($0) }

            // flacky tes
            expect(splitString1).to(contain(formData1))
            expect(splitString1).to(contain(formData2))
            expect(splitString2).to(contain(formData1))
            expect(splitString2).to(contain(formData2))

        }

        it("appends additional multipart body parts in endpointClosure") {
            let multipartData1 = Moya.MultipartFormBodyPart(provider: .data("test1".data(using: .utf8)!), name: "test1")
            let multipartData2 = Moya.MultipartFormBodyPart(provider: .data("test2".data(using: .utf8)!), name: "test2")

            let providedMultipartData = [multipartData1]
            let sentMultipartData = [multipartData1, multipartData2]

            _ = provider.request(HTTPBin.uploadMultipartBodyParts(providedMultipartData, nil)) { _ in }
            let stringData1 = session.uploadMultipartString!

            let multipartFormData = MultipartFormData(parts: sentMultipartData)

            let requestMultipartFormData = RequestMultipartFormData(fileManager: multipartFormData.fileManager, boundary: multipartFormData.boundary)
            requestMultipartFormData.applyMoyaMultipartFormData(multipartFormData)
            let stringData2 = String(decoding: try! requestMultipartFormData.encode(), as: UTF8.self)

            let formData1 = "data; name=\"test1\"\r\n\r\ntest1\r\n"
            let formData2 = "data; name=\"test2\"\r\n\r\ntest2\r\n"

            let splitString1 = stringData1.split(separator: "-").map { String($0) }
            let splitString2 = stringData2.split(separator: "-").map { String($0) }

            // flacky tes
            expect(splitString1).to(contain(formData1))
            expect(splitString1).to(contain(formData2))
            expect(splitString2).to(contain(formData1))
            expect(splitString2).to(contain(formData2))

        }
    }
}

final class SessionMock: Alamofire.Session {

    var uploadMultipartString: String?

    override func upload(multipartFormData: Alamofire.MultipartFormData, with request: any URLRequestConvertible, usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold, interceptor: (any RequestInterceptor)? = nil, fileManager: FileManager = .default) -> UploadRequest {
        let data = try! multipartFormData.encode()
        uploadMultipartString = String(decoding: data, as: UTF8.self)

        return super.upload(multipartFormData: multipartFormData, with: request, usingThreshold: encodingMemoryThreshold, interceptor: interceptor, fileManager: fileManager)
    }
}
