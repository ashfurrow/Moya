import Quick
import Moya
import Nimble
import Foundation

final class NonUpdatingRequestEndpointConfiguration: QuickConfiguration {
    override static func configure(_ configuration: Configuration) {
        sharedExamples("endpoint with no request property changed") { (context: SharedExampleContext) in
            let task = context()["task"] as! Task
            let oldEndpoint = context()["endpoint"] as! Endpoint
            let endpoint = oldEndpoint.replacing(task: task)
            let request = try! endpoint.urlRequest()

            it("didn't update any of the request properties") {
                expect(request.httpBody).to(beNil())
                expect(request.url?.absoluteString).to(equal(endpoint.url))
                expect(request.allHTTPHeaderFields).to(equal(endpoint.httpHeaderFields))
                expect(request.httpMethod).to(equal(endpoint.method.rawValue))
            }
        }
    }
}

final class ParametersEncodedEndpointConfiguration: QuickConfiguration {
    override static func configure(_ configuration: Configuration) {
        sharedExamples("endpoint with encoded parameters") { (context: SharedExampleContext) in
            let parameters = context()["parameters"] as! [String: Any]
            let encoding = context()["encoding"] as! any ParameterEncoding
            let endpoint = context()["endpoint"] as! Endpoint
            let request = try! endpoint.urlRequest()

            it("updated the request correctly") {
                let newEndpoint = endpoint.replacing(task: .requestPlain)
                let newRequest = try! newEndpoint.urlRequest()
                let newEncodedRequest = try? encoding.encode(newRequest, with: parameters)

                expect(request.httpBody).to(equal(newEncodedRequest?.httpBody))
                expect(request.url?.absoluteString).to(equal(newEncodedRequest?.url?.absoluteString))
                expect(request.allHTTPHeaderFields).to(equal(newEncodedRequest?.allHTTPHeaderFields))
                expect(request.httpMethod).to(equal(newEncodedRequest?.httpMethod))
            }
        }
    }
}

final class EndpointSpec: QuickSpec {

    private var simpleGitHubEndpoint: Endpoint {
        let target: GitHub = .zen
        let headerFields = ["Title": "Dominar"]
        return Endpoint(url: url(target), sampleResponseClosure: {.networkResponse(200, target.sampleData)}, method: Moya.Method.get, task: .requestPlain, httpHeaderFields: headerFields)
    }

    override func spec() {
        var endpoint: Endpoint!

        beforeEach {
            endpoint = self.simpleGitHubEndpoint
        }

        it("returns a new endpoint for adding(newHTTPHeaderFields:)") {
            let agent = "Zalbinian"
            let newEndpoint = endpoint.adding(newHTTPHeaderFields: ["User-Agent": agent])
            let newEndpointAgent = newEndpoint.httpHeaderFields?["User-Agent"]

            // Make sure our closure updated the sample response, as proof that it can modify the Endpoint
            expect(newEndpointAgent).to(equal(agent))

            // Compare other properties to ensure they've been copied correctly
            expect(newEndpoint.url).to(equal(endpoint.url))
            expect(newEndpoint.method).to(equal(endpoint.method))
        }

        it("returns a nil urlRequest for an invalid URL") {
            let badEndpoint = Endpoint(url: "some invalid URL", sampleResponseClosure: { .networkResponse(200, Data()) }, method: .get, task: .requestPlain, httpHeaderFields: nil)
            let urlRequest = try? badEndpoint.urlRequest()
            expect(urlRequest).to(beNil())
        }

        describe("successful converting to urlRequest") {
            context("when task is .requestPlain") {
                itBehavesLike("endpoint with no request property changed") {
                    ["task": Task.requestPlain, "endpoint": self.simpleGitHubEndpoint]
                }
            }

            context("when task is .uploadFile") {
                itBehavesLike("endpoint with no request property changed") {
                    ["task": Task.uploadFile(URL(string: "https://google.com")!), "endpoint": self.simpleGitHubEndpoint]
                }
            }

            context("when task is .uploadMultipart") {
                itBehavesLike("endpoint with no request property changed") {
                    ["task": Task.uploadMultipart([]), "endpoint": self.simpleGitHubEndpoint]
                }
            }

            context("when task is .uploadMultipartFormData") {
                itBehavesLike("endpoint with no request property changed") {
                    ["task": Task.uploadMultipartFormData([]), "endpoint": self.simpleGitHubEndpoint]
                }
            }

            context("when task is .downloadDestination") {
                itBehavesLike("endpoint with no request property changed") {
                    let destination: DownloadDestination = { url, response in
                        return (destinationURL: url, options: [])
                    }
                    return ["task": Task.downloadDestination(destination), "endpoint": self.simpleGitHubEndpoint]
                }
            }

            context("when task is .requestParameters") {
                itBehavesLike("endpoint with encoded parameters") {
                    let parameters = ["Nemesis": "Harvey"]
                    let encoding = JSONEncoding.default
                    let endpoint = self.simpleGitHubEndpoint.replacing(task: .requestParameters(parameters: parameters, encoding: encoding))
                    return ["parameters": parameters, "encoding": encoding, "endpoint": endpoint]
                }
            }

            context("when task is .downloadParameters") {
                itBehavesLike("endpoint with encoded parameters") {
                    let parameters = ["Nemesis": "Harvey"]
                    let encoding = JSONEncoding.default
                    let destination: DownloadDestination = { url, response in
                        return (destinationURL: url, options: [])
                    }
                    let endpoint = self.simpleGitHubEndpoint.replacing(task: .downloadParameters(parameters: parameters, encoding: encoding, destination: destination))
                    return ["parameters": parameters, "encoding": encoding, "endpoint": endpoint]
                }
            }

            context("when task is .requestData") {
                var data: Data!
                var request: URLRequest!

                beforeEach {
                    data = "test data".data(using: .utf8)
                    endpoint = endpoint.replacing(task: .requestData(data))
                    request = try! endpoint.urlRequest()
                }

                it("updates httpBody") {
                    expect(request.httpBody).to(equal(data))
                }

                it("doesn't update any of the other properties") {
                    expect(request.url?.absoluteString).to(equal(endpoint.url))
                    expect(request.allHTTPHeaderFields).to(equal(endpoint.httpHeaderFields))
                    expect(request.httpMethod).to(equal(endpoint.method.rawValue))
                }
            }

            context("when task is .requestJSONEncodable") {
                var issue: Issue!
                var request: URLRequest!

                beforeEach {
                    issue = Issue(title: "Hello, Moya!", createdAt: Date(), rating: 0)
                    endpoint = endpoint.replacing(task: .requestJSONEncodable(issue))
                    request = try! endpoint.urlRequest()
                }

                it("updates httpBody") {
                    let expectedIssue = try! JSONDecoder().decode(Issue.self, from: request.httpBody!)
                    expect(issue.createdAt).to(equal(expectedIssue.createdAt))
                    expect(issue.title).to(equal(expectedIssue.title))
                }

                it("updates headers to include Content-Type: application/json") {
                    let contentTypeHeaders = ["Content-Type": "application/json"]
                    let initialHeaderFields = endpoint.httpHeaderFields ?? [:]
                    let expectedHTTPHeaderFields = initialHeaderFields.merging(contentTypeHeaders) { initialValue, _ in initialValue }
                    expect(request.allHTTPHeaderFields).to(equal(expectedHTTPHeaderFields))
                }

                it("doesn't update any of the other properties") {
                    expect(request.url?.absoluteString).to(equal(endpoint.url))
                    expect(request.httpMethod).to(equal(endpoint.method.rawValue))
                }
            }

            context("when task is .requestCustomJSONEncodable") {
                var issue: Issue!
                var request: URLRequest!

                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .formatted(formatter)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(formatter)

                beforeEach {
                    issue = Issue(title: "Hello, Moya!", createdAt: Date(), rating: 0)
                    endpoint = endpoint.replacing(task: .requestCustomJSONEncodable(issue, encoder: encoder))
                    request = try! endpoint.urlRequest()
                }

                it("updates httpBody") {
                    let expectedIssue = try! decoder.decode(Issue.self, from: request.httpBody!)
                    expect(formatter.string(from: issue.createdAt)).to(equal(formatter.string(from: expectedIssue.createdAt)))
                    expect(issue.title).to(equal(expectedIssue.title))
                }

                it("updates headers to include Content-Type: application/json") {
                    let contentTypeHeaders = ["Content-Type": "application/json"]
                    let initialHeaderFields = endpoint.httpHeaderFields ?? [:]
                    let expectedHTTPHeaderFields = initialHeaderFields.merging(contentTypeHeaders) { initialValue, _ in initialValue }
                    expect(request.allHTTPHeaderFields).to(equal(expectedHTTPHeaderFields))
                }

                it("doesn't update any of the other properties") {
                    expect(request.url?.absoluteString).to(equal(endpoint.url))
                    expect(request.httpMethod).to(equal(endpoint.method.rawValue))
                }
            }

            context("when task is .requestCompositeData") {
                var parameters: [String: Any]!
                var data: Data!
                var request: URLRequest!

                beforeEach {
                    parameters = ["Nemesis": "Harvey"]
                    data = "test data".data(using: .utf8)
                    endpoint = endpoint.replacing(task: .requestCompositeData(bodyData: data, urlParameters: parameters))
                    request = try! endpoint.urlRequest()
                }

                it("updates url") {
                    let expectedUrl = endpoint.url + "?Nemesis=Harvey"
                    expect(request.url?.absoluteString).to(equal(expectedUrl))
                }

                it("updates httpBody") {
                    expect(request.httpBody).to(equal(data))
                }

                it("doesn't update any of the other properties") {
                    expect(request?.allHTTPHeaderFields).to(equal(endpoint.httpHeaderFields))
                    expect(request?.httpMethod).to(equal(endpoint.method.rawValue))
                }
            }

            context("when task is .requestCompositeParameters") {
                var bodyParameters: [String: Any]!
                var urlParameters: [String: Any]!
                var encoding: (any ParameterEncoding)!
                var request: URLRequest!

                beforeEach {
                    bodyParameters = ["Nemesis": "Harvey"]
                    urlParameters = ["Harvey": "Nemesis"]
                    encoding = JSONEncoding.default
                    endpoint = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: bodyParameters, bodyEncoding: encoding, urlParameters: urlParameters))
                    request = try! endpoint.urlRequest()
                }

                it("updates url") {
                    let expectedUrl = endpoint.url + "?Harvey=Nemesis"
                    expect(request.url?.absoluteString).to(equal(expectedUrl))
                }

                it("updates the request correctly") {
                    let newEndpoint = endpoint.replacing(task: .requestPlain)
                    let newRequest = try! newEndpoint.urlRequest()
                    let newEncodedRequest = try? encoding.encode(newRequest, with: bodyParameters)

                    expect(request.httpBody).to(equal(newEncodedRequest?.httpBody))
                    expect(request.allHTTPHeaderFields).to(equal(newEncodedRequest?.allHTTPHeaderFields))
                    expect(request.httpMethod).to(equal(newEncodedRequest?.httpMethod))
                }
            }

            context("when task is .uploadCompositeMultipart") {
                var urlParameters: [String: Any]!
                var request: URLRequest!

                beforeEach {
                    urlParameters = ["Harvey": "Nemesis"]
                    endpoint = endpoint.replacing(task: .uploadCompositeMultipart([], urlParameters: urlParameters))
                    request = try! endpoint.urlRequest()
                }

                it("updates url") {
                    let expectedUrl = endpoint.url + "?Harvey=Nemesis"
                    expect(request.url?.absoluteString).to(equal(expectedUrl))
                }
            }

            context("when task is .uploadCompositeMultipartFormData") {
                var urlParameters: [String: Any]!
                var request: URLRequest!

                beforeEach {
                    urlParameters = ["Harvey": "Nemesis"]
                    endpoint = endpoint.replacing(task: .uploadCompositeMultipartFormData([], urlParameters: urlParameters))
                    request = try! endpoint.urlRequest()
                }

                it("updates url") {
                    let expectedUrl = endpoint.url + "?Harvey=Nemesis"
                    expect(request.url?.absoluteString).to(equal(expectedUrl))
                }
            }
        }

        describe("unsuccessful converting to urlRequest") {
            context("when url String is invalid") {
                it("throws a .requestMapping error") {
                    let badEndpoint = Endpoint(url: "some invalid URL", sampleResponseClosure: { .networkResponse(200, Data()) }, method: .get, task: .requestPlain, httpHeaderFields: nil)
                    let expectedError = MoyaError.requestMapping("some invalid URL")
                    var recievedError: MoyaError?
                    do {
                        _ = try badEndpoint.urlRequest()
                    } catch {
                        recievedError = error as? MoyaError
                    }
                    expect(recievedError).toNot(beNil())
                    expect(recievedError).to(beOfSameErrorType(expectedError))
                }
            }

            context("when parameter encoding is unsuccessful") {
                it("throws a .parameterEncoding error") {

                    // Non-serializable type to cause serialization error
                    class InvalidParameter {}

                    endpoint = endpoint.replacing(task: .requestParameters(parameters: ["": InvalidParameter()], encoding: PropertyListEncoding.default))
                    let cocoaError = NSError(domain: "NSCocoaErrorDomain", code: 3851, userInfo: ["NSDebugDescription": "Property list invalid for format: 100 (property lists cannot contain objects of type 'CFType')"])
                    let expectedError = MoyaError.parameterEncoding(cocoaError)
                    var recievedError: MoyaError?

                    do {
                        _ = try endpoint.urlRequest()
                    } catch {
                        recievedError = error as? MoyaError
                    }
                    expect(recievedError).toNot(beNil())
                    expect(recievedError).to(beOfSameErrorType(expectedError))
                }
            }

            context("when JSONEncoder set with incorrect parameters") {
                it("throws a .encodableMapping error") {
                    let encoder = JSONEncoder()

                    let issue = Issue(title: "Hello, Moya!", createdAt: Date(), rating: Float.infinity)
                    endpoint = endpoint.replacing(task: .requestCustomJSONEncodable(issue, encoder: encoder))

                    let expectedError = MoyaError.encodableMapping(EncodingError.invalidValue(Float.infinity, EncodingError.Context(codingPath: [Issue.CodingKeys.rating], debugDescription: "Unable to encode Float.infinity directly in JSON. Use JSONEncoder.NonConformingFloatEncodingStrategy.convertToString to specify how the value should be encoded.", underlyingError: nil)))
                    var recievedError: MoyaError?

                    do {
                        _ = try endpoint.urlRequest()
                    } catch {
                        recievedError = error as? MoyaError
                    }
                    expect(recievedError).toNot(beNil())
                    expect(recievedError).to(beOfSameErrorType(expectedError))
                }
            }

            #if !SWIFT_PACKAGE
            context("when task is .requestCompositeParameters") {
                it("throws an error when bodyEncoding is an URLEncoding.queryString") {
                    endpoint = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: [:], bodyEncoding: URLEncoding.queryString, urlParameters: [:]))
                    expect({ _ = try? endpoint.urlRequest() }).to(throwAssertion())
                }

                it("throws an error when bodyEncoding is an URLEncoding.default") {
                    endpoint = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: [:], bodyEncoding: URLEncoding.default, urlParameters: [:]))
                    expect({ _ = try? endpoint.urlRequest() }).to(throwAssertion())
                }

                it("doesn't throw an error when bodyEncoding is an URLEncoding.httpBody") {
                    endpoint = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: [:], bodyEncoding: URLEncoding.httpBody, urlParameters: [:]))
                    expect({ _ = try? endpoint.urlRequest() }).toNot(throwAssertion())
                }
            }
            #endif
        }

        describe("given endpoint comparison") {
            context("when task is .uploadMultipart") {
                it("should correctly acknowledge as equal for the same url, headers and form data") {
                    endpoint = endpoint.replacing(task: .uploadMultipart([MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")]))
                    let endpointToCompare = endpoint.replacing(task: .uploadMultipart([MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")]))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different form data") {
                    endpoint = endpoint.replacing(task: .uploadMultipart([MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")]))
                    let endpointToCompare = endpoint.replacing(task: .uploadMultipart([MultipartFormBodyPart(provider: .data("test1".data(using: .utf8)!), name: "test")]))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .uploadMultipartFormData") {
                it("should correctly acknowledge as equal for the same url, headers and form data") {
                    endpoint = endpoint.replacing(task: .uploadMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")])))
                    let endpointToCompare = endpoint.replacing(task: .uploadMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")])))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different form data") {
                    endpoint = endpoint.replacing(task: .uploadMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")])))
                    let endpointToCompare = endpoint.replacing(task: .uploadMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test1".data(using: .utf8)!), name: "test")])))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .uploadCompositeMultipart") {
                it("should correctly acknowledge as equal for the same url, headers and form data") {
                    endpoint = endpoint.replacing(task: .uploadCompositeMultipart([MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")], urlParameters: [:]))
                    let endpointToCompare = endpoint.replacing(task: .uploadCompositeMultipart([MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")], urlParameters: [:]))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different form data") {
                    endpoint = endpoint.replacing(task: .uploadCompositeMultipart([MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")], urlParameters: [:]))
                    let endpointToCompare = endpoint.replacing(task: .uploadCompositeMultipart([MultipartFormBodyPart(provider: .data("test1".data(using: .utf8)!), name: "test")], urlParameters: [:]))

                    expect(endpoint) != endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different url parameters") {
                    endpoint = endpoint.replacing(task: .uploadCompositeMultipartFormData([MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")], urlParameters: ["test": "test2"]))
                    let endpointToCompare = endpoint.replacing(task: .uploadCompositeMultipartFormData([MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")], urlParameters: ["test": "test3"]))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .uploadCompositeMultipartFormData") {
                it("should correctly acknowledge as equal for the same url, headers and form data") {
                    endpoint = endpoint.replacing(task: .uploadCompositeMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")]), urlParameters: [:]))
                    let endpointToCompare = endpoint.replacing(task: .uploadCompositeMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")]), urlParameters: [:]))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different form data") {
                    endpoint = endpoint.replacing(task: .uploadCompositeMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")]), urlParameters: [:]))
                    let endpointToCompare = endpoint.replacing(task: .uploadCompositeMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test1".data(using: .utf8)!), name: "test")]), urlParameters: [:]))

                    expect(endpoint) != endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different url parameters") {
                    endpoint = endpoint.replacing(task: .uploadCompositeMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")]), urlParameters: ["test": "test2"]))
                    let endpointToCompare = endpoint.replacing(task: .uploadCompositeMultipartFormData(MultipartFormData(parts: [MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "test")]), urlParameters: ["test": "test3"]))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .uploadFile") {
                it("should correctly acknowledge as equal for the same url, headers and file") {
                    endpoint = endpoint.replacing(task: .uploadFile(URL(string: "https://google.com")!))
                    let endpointToCompare = endpoint.replacing(task: .uploadFile(URL(string: "https://google.com")!))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different file") {
                    endpoint = endpoint.replacing(task: .uploadFile(URL(string: "https://google.com")!))
                    let endpointToCompare = endpoint.replacing(task: .uploadFile(URL(string: "https://google.com?q=test")!))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .downloadDestination") {
                it("should correctly acknowledge as equal for the same url, headers and download destination") {
                    endpoint = endpoint.replacing(task: .downloadDestination { temporaryUrl, _ in
                        return (destinationURL: temporaryUrl, options: [])
                    })
                    let endpointToCompare = endpoint.replacing(task: .downloadDestination { temporaryUrl, _ in
                        return (destinationURL: temporaryUrl, options: [])
                    })

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as equal for the same url, headers and different download destination") {
                    endpoint = endpoint.replacing(task: .downloadDestination { temporaryUrl, _ in
                        return (destinationURL: temporaryUrl, options: [])
                    })
                    let endpointToCompare = endpoint.replacing(task: .downloadDestination { _, _ in
                        return (destinationURL: URL(string: "https://google.com")!, options: [])
                    })

                    expect(endpoint) == endpointToCompare
                }
            }

            context("when task is .downloadParameters") {
                it("should correctly acknowledge as equal for the same url, headers and download destination") {
                    endpoint = endpoint.replacing(task: .downloadParameters(parameters: ["test": "test2"], encoding: JSONEncoding.default, destination: { temporaryUrl, _ in
                        return (destinationURL: temporaryUrl, options: [])
                    }))
                    let endpointToCompare = endpoint.replacing(task: .downloadParameters(parameters: ["test": "test2"], encoding: JSONEncoding.default, destination: { temporaryUrl, _ in
                        return (destinationURL: temporaryUrl, options: [])
                    }))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers, download destionation and different parameters") {
                    endpoint = endpoint.replacing(task: .downloadParameters(parameters: ["test": "test2"], encoding: JSONEncoding.default, destination: { temporaryUrl, _ in
                        return (destinationURL: temporaryUrl, options: [])
                    }))
                    let endpointToCompare = endpoint.replacing(task: .downloadParameters(parameters: ["test": "test3"], encoding: JSONEncoding.default, destination: { temporaryUrl, _ in
                        return (destinationURL: temporaryUrl, options: [])
                    }))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .requestCompositeData") {
                it("should correctly acknowledge as equal for the same url, headers, body and url parameters") {
                    endpoint = endpoint.replacing(task: .requestCompositeData(bodyData: "test".data(using: .utf8)!, urlParameters: ["test": "test1"]))
                    let endpointToCompare = endpoint.replacing(task: .requestCompositeData(bodyData: "test".data(using: .utf8)!, urlParameters: ["test": "test1"]))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers, body and different url parameters") {
                    endpoint = endpoint.replacing(task: .requestCompositeData(bodyData: "test".data(using: .utf8)!, urlParameters: ["test": "test1"]))
                    let endpointToCompare = endpoint.replacing(task: .requestCompositeData(bodyData: "test".data(using: .utf8)!, urlParameters: ["test": "test2"]))

                    expect(endpoint) != endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers, url parameters and different body") {
                    endpoint = endpoint.replacing(task: .requestCompositeData(bodyData: "test".data(using: .utf8)!, urlParameters: ["test": "test1"]))
                    let endpointToCompare = endpoint.replacing(task: .requestCompositeData(bodyData: "test2".data(using: .utf8)!, urlParameters: ["test": "test1"]))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .requestPlain") {
                it("should correctly acknowledge as equal for the same url, headers and body") {
                    endpoint = endpoint.replacing(task: .requestPlain)
                    let endpointToCompare = endpoint.replacing(task: .requestPlain)

                    expect(endpoint) == endpointToCompare
                }
            }

            context("when task is .requestData") {
                it("should correctly acknowledge as equal for the same url, headers and data") {
                    endpoint = endpoint.replacing(task: .requestData("test".data(using: .utf8)!))
                    let endpointToCompare = endpoint.replacing(task: .requestData("test".data(using: .utf8)!))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different data") {
                    endpoint = endpoint.replacing(task: .requestData("test".data(using: .utf8)!))
                    let endpointToCompare = endpoint.replacing(task: .requestData("test1".data(using: .utf8)!))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .requestJSONEncodable") {
                it("should correctly acknowledge as equal for the same url, headers and encodable") {
                    let date = Date()
                    endpoint = endpoint.replacing(task: .requestJSONEncodable(Issue(title: "T", createdAt: date, rating: 0)))
                    let endpointToCompare = endpoint.replacing(task: .requestJSONEncodable(Issue(title: "T", createdAt: date, rating: 0)))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different encodable") {
                    let date = Date()
                    endpoint = endpoint.replacing(task: .requestJSONEncodable(Issue(title: "T", createdAt: date, rating: 0)))
                    let endpointToCompare = endpoint.replacing(task: .requestJSONEncodable(Issue(title: "Ta", createdAt: date, rating: 0)))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .requestParameters") {
                it("should correctly acknowledge as equal for the same url, headers and parameters") {
                    endpoint = endpoint.replacing(task: .requestParameters(parameters: ["test": "test1"], encoding: URLEncoding.queryString))
                    let endpointToCompare = endpoint.replacing(task: .requestParameters(parameters: ["test": "test1"], encoding: URLEncoding.queryString))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers and different parameters") {
                    endpoint = endpoint.replacing(task: .requestParameters(parameters: ["test": "test1"], encoding: URLEncoding.queryString))
                    let endpointToCompare = endpoint.replacing(task: .requestParameters(parameters: ["test": "test2"], encoding: URLEncoding.queryString))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .requestCompositeParameters") {
                it("should correctly acknowledge as equal for the same url, headers, body and url parameters") {
                    endpoint = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: ["test": "test1"], bodyEncoding: JSONEncoding.default, urlParameters: ["url_test": "test1"]))
                    let endpointToCompare = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: ["test": "test1"], bodyEncoding: JSONEncoding.default, urlParameters: ["url_test": "test1"]))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers, body parameters and different url parameters") {
                    endpoint = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: ["test": "test1"], bodyEncoding: JSONEncoding.default, urlParameters: ["url_test": "test1"]))
                    let endpointToCompare = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: ["test": "test1"], bodyEncoding: JSONEncoding.default, urlParameters: ["url_test": "test2"]))

                    expect(endpoint) != endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers, url parameters and different body parameters") {
                    endpoint = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: ["test": "test1"], bodyEncoding: JSONEncoding.default, urlParameters: ["url_test": "test1"]))
                    let endpointToCompare = endpoint.replacing(task: .requestCompositeParameters(bodyParameters: ["test": "test2"], bodyEncoding: JSONEncoding.default, urlParameters: ["url_test": "test1"]))

                    expect(endpoint) != endpointToCompare
                }
            }

            context("when task is .requestCustomJSONEncodable") {
                it("should correctly acknowledge as equal for the same url, headers, encodable and encoder") {
                    let date = Date()
                    endpoint = endpoint.replacing(task: .requestCustomJSONEncodable(Issue(title: "T", createdAt: date, rating: 0), encoder: JSONEncoder()))
                    let endpointToCompare = endpoint.replacing(task: .requestCustomJSONEncodable(Issue(title: "T", createdAt: date, rating: 0), encoder: JSONEncoder()))

                    expect(endpoint) == endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers, encoder and different encodable") {
                    let date = Date()
                    endpoint = endpoint.replacing(task: .requestCustomJSONEncodable(Issue(title: "T", createdAt: date, rating: 0), encoder: JSONEncoder()))
                    let endpointToCompare = endpoint.replacing(task: .requestCustomJSONEncodable(Issue(title: "Ta", createdAt: date, rating: 0), encoder: JSONEncoder()))

                    expect(endpoint) != endpointToCompare
                }

                it("should correctly acknowledge as not equal for the same url, headers, encodable and different encoder") {
                    let date = Date()
                    endpoint = endpoint.replacing(task: .requestCustomJSONEncodable(Issue(title: "T", createdAt: date, rating: 0), encoder: JSONEncoder()))
                    let snakeEncoder = JSONEncoder()
                    snakeEncoder.keyEncodingStrategy = .convertToSnakeCase
                    let endpointToCompare = endpoint.replacing(task: .requestCustomJSONEncodable(Issue(title: "T", createdAt: date, rating: 0), encoder: snakeEncoder))

                    expect(endpoint) != endpointToCompare
                }
            }
        }
    }
}

enum Empty {
}

extension Empty: TargetType {
    // None of these matter since the Empty has no cases and can't be instantiated.
    var baseURL: URL { URL(string: "http://example.com")! }
    var path: String { "" }
    var method: Moya.Method { .get }
    var parameters: [String: Any]? { nil }
    var parameterEncoding: any ParameterEncoding { URLEncoding.default }
    var task: Task { .requestPlain }
    var sampleData: Data { Data() }
    var headers: [String: String]? { nil }
}
