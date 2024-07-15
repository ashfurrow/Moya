#if canImport(Combine)
import Quick
import Nimble
import Combine
import CombineMoya

#if canImport(OHHTTPStubs)
    import OHHTTPStubs
#elseif canImport(OHHTTPStubsSwift)
    import OHHTTPStubsCore
    import OHHTTPStubsSwift
#endif

@testable import Moya

final class MoyaProviderCombineSpec: QuickSpec {

    override func spec() {
        if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            describe("provider") {
                var provider: MoyaProvider<GitHub>!

                beforeEach {
                    provider = MoyaProvider<GitHub>(stubClosure: MoyaProvider.immediatelyStub)
                }

                it("emits one Response object") {
                    var calls = 0

                    _ = provider.requestPublisher(.zen)
                        .sink(receiveCompletion: { completion in
                            switch completion {
                            case let .failure(error):
                                fail("errored: \(error)")
                            default:
                                ()
                            }
                        }, receiveValue: { _ in
                            calls += 1
                        })

                    expect(calls).to(equal(1))
                }

                it("emits stubbed data for zen request") {
                    var responseData: Data?

                    let target: GitHub = .zen
                    _ = provider.requestPublisher(target)
                        .sink(receiveCompletion: { completion in
                            switch completion {
                            case let .failure(error):
                                fail("errored: \(error)")
                            default:
                                ()
                            }
                        }, receiveValue: { response in
                            responseData = response.data
                        })

                    expect(responseData).to(equal(target.sampleData))
                }

                it("maps JSON data correctly for user profile request") {
                    var receivedResponse: [String: Any]?

                    let target: GitHub = .userProfile("ashfurrow")
                    _ = provider.requestPublisher(target)
                        .mapJSON()
                        .sink(receiveCompletion: { completion in
                            switch completion {
                            case let .failure(error):
                                fail("errored: \(error)")
                            default:
                                ()
                            }
                        }, receiveValue: { response in
                            receivedResponse = response as? [String: Any]
                        })

                    expect(receivedResponse).toNot(beNil())
                }
            }

            describe("failing") {
                var provider: MoyaProvider<GitHub>!

                beforeEach {
                    provider = MoyaProvider<GitHub>(endpointClosure: failureEndpointClosure, stubClosure: MoyaProvider.immediatelyStub)
                }

                it("emits the correct error message") {
                    var receivedError: MoyaError?

                    _ = provider.requestPublisher(.zen)
                        .sink(receiveCompletion: { completion in
                            switch completion {
                            case let .failure(error):
                                receivedError = error
                            case .finished:
                                ()
                            }
                        }, receiveValue: { _ in
                            fail("should have errored")
                        })

                    switch receivedError {
                    case .some(.underlying(let error, _)):
                        expect(error.localizedDescription) == "Houston, we have a problem"
                    default:
                        fail("expected an Underlying error that Houston has a problem")
                    }
                }

                it("emits an error") {
                    var errored = false

                    let target: GitHub = .zen
                    _ = provider.requestPublisher(target)
                        .sink(receiveCompletion: { completion in
                            switch completion {
                            case .failure:
                                errored = true
                            case .finished:
                                ()
                            }
                        }, receiveValue: { _ in
                            fail("should have errored")
                        })

                    expect(errored).to(beTrue())
                }
            }

            describe("a reactive provider") {
                var provider: MoyaProvider<GitHub>!

                beforeEach {
                    HTTPStubs.stubRequests(passingTest: {$0.url!.path == "/zen"}, withStubResponse: { _ in
                        return HTTPStubsResponse(data: GitHub.zen.sampleData, statusCode: 200, headers: nil)
                    })
                    provider = MoyaProvider<GitHub>(trackInflights: true)
                }

                it("emits identical response for inflight requests") {
                    let target: GitHub = .zen
                    let signalProducer1 = provider.requestPublisher(target)
                    let signalProducer2 = provider.requestPublisher(target)

                    expect(provider.inflightRequests.keys.count).to(equal(0))

                    var receivedResponse: Moya.Response!

                    // If we do not name the variable, Combine's Cancellable will cancel itself
                    let cancellable1 = signalProducer1.sink(receiveCompletion: { completion in
                        switch completion {
                        case let .failure(error):
                            fail("errored: \(error)")
                        default:
                            ()
                        }
                    }, receiveValue: { response in
                        receivedResponse = response
                        expect(provider.inflightRequests.count).to(equal(1))
                    })

                    // If we do not name the variable, Combine's Cancellable will cancel itself
                    let cancellable2 = signalProducer2.sink(receiveCompletion: { completion in
                        switch completion {
                        case let .failure(error):
                            fail("errored: \(error)")
                        default:
                            ()
                        }
                    }, receiveValue: { response in
                        expect(receivedResponse).toNot(beNil())
                        expect(receivedResponse).to(beIdenticalToResponse(response))
                        expect(provider.inflightRequests.count).to(equal(1))
                    })

                    // This is to silence the warning about unused variables
                    _ = cancellable1
                    _ = cancellable2

                    // Allow for network request to complete
                    expect(provider.inflightRequests.count).toEventually(equal(0))
                }
            }

            describe("a provider with progress tracking") {
                var provider: MoyaProvider<GitHubUserContent>!

                beforeEach {
                    //delete downloaded filed before each test
                    let directoryURLs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
                    let file = directoryURLs.first!.appendingPathComponent("logo_github.png")
                    try? FileManager.default.removeItem(at: file)

                    //`responseTime(-4)` equals to 1000 bytes at a time. The sample data is 4000 bytes.
                    HTTPStubs.stubRequests(passingTest: {$0.url!.path.hasSuffix("logo_github.png")}, withStubResponse: { _ in
                        return HTTPStubsResponse(data: GitHubUserContent.downloadMoyaWebContent("logo_github.png").sampleData, statusCode: 200, headers: nil).responseTime(-4)
                    })
                    provider = MoyaProvider<GitHubUserContent>()
                }

                it("tracks progress of request") {
                    let target: GitHubUserContent = .downloadMoyaWebContent("logo_github.png")

                    let expectedNextProgressValues = [0.25, 0.5, 0.75, 1.0, 1.0]
                    let expectedNextResponseCount = 1
                    let expectedErrorEventsCount = 0
                    let expectedCompletedEventsCount = 1
                    let timeout = DispatchTimeInterval.seconds(5)

                    var nextProgressValues: [Double] = []
                    var nextResponseCount = 0
                    var errorEventsCount = 0
                    var completedEventsCount = 0

                    let cancellable = provider.requestWithProgressPublisher(target)
                        .sink(receiveCompletion: { completion in
                            switch completion {
                            case .failure:
                                errorEventsCount += 1
                            case .finished:
                                completedEventsCount += 1
                            }
                        }, receiveValue: { response in
                            nextProgressValues.append(response.progress)

                            if response.response != nil { nextResponseCount += 1 }
                        })

                    // This is to silence the warning about unused variables
                    _ = cancellable

                    expect(completedEventsCount).toEventually(equal(expectedCompletedEventsCount), timeout: timeout)
                    expect(errorEventsCount).toEventually(equal(expectedErrorEventsCount), timeout: timeout)
                    expect(nextResponseCount).toEventually(equal(expectedNextResponseCount), timeout: timeout)
                    expect(nextProgressValues).toEventually(equal(expectedNextProgressValues), timeout: timeout)
                }

                describe("a custom callback queue") {
                    var stubDescriptor: (any HTTPStubsDescriptor)!

                    beforeEach {
                        stubDescriptor = HTTPStubs.stubRequests(passingTest: {$0.url!.path == "/zen"}, withStubResponse: { _ in
                            return HTTPStubsResponse(data: GitHub.zen.sampleData, statusCode: 200, headers: nil)
                        })
                    }

                    afterEach {
                        HTTPStubs.removeStub(stubDescriptor)
                    }

                    describe("a provider with a predefined callback queue") {
                        var provider: MoyaProvider<GitHub>!
                        var callbackQueue: DispatchQueue!

                        beforeEach {
                            callbackQueue = DispatchQueue(label: UUID().uuidString)
                            provider = MoyaProvider<GitHub>(callbackQueue: callbackQueue)
                        }

                        context("the callback queue is provided with the request") {
                            it("invokes the callback on the request queue") {
                                let requestQueue = DispatchQueue(label: UUID().uuidString)
                                var callbackQueueLabel: String?

                                let cancellable = provider.requestPublisher(.zen, callbackQueue: requestQueue)
                                    .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                                        let label = DispatchQueue.currentLabel

                                        DispatchQueue.main.async {
                                            callbackQueueLabel = label
                                        }
                                    })

                                // This is to silence the warning about unused variables
                                _ = cancellable

                                expect(callbackQueueLabel).toEventually(equal(requestQueue.label))
                            }
                        }

                        context("the queueless request method is invoked") {
                            it("invokes the callback on the provider queue") {
                                var callbackQueueLabel: String?

                                let cancellable = provider.requestPublisher(.zen)
                                    .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                                        let label = DispatchQueue.currentLabel

                                        DispatchQueue.main.async {
                                            callbackQueueLabel = label
                                        }
                                    })
                                // This is to silence the warning about unused variables
                                _ = cancellable

                                expect(callbackQueueLabel).toEventually(equal(callbackQueue.label))
                            }
                        }
                    }

                    describe("a provider without a predefined queue") {
                        var provider: MoyaProvider<GitHub>!

                        beforeEach {
                            provider = MoyaProvider<GitHub>()
                        }

                        context("the queue is provided with the request") {
                            it("invokes the callback on the specified queue") {
                                let requestQueue = DispatchQueue(label: UUID().uuidString)
                                var callbackQueueLabel: String?

                                let cancellable = provider.requestPublisher(.zen, callbackQueue: requestQueue)
                                    .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                                        let label = DispatchQueue.currentLabel

                                        DispatchQueue.main.async {
                                            callbackQueueLabel = label
                                        }
                                    })

                                // This is to silence the warning about unused variables
                                _ = cancellable

                                expect(callbackQueueLabel).toEventually(equal(requestQueue.label))
                            }
                        }

                        context("the queue is not provided with the request") {
                            it("invokes the callback on the main queue") {
                                var callbackQueueLabel: String?

                                let cancellable = provider.requestPublisher(.zen)
                                    .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                                        let label = DispatchQueue.currentLabel

                                        DispatchQueue.main.async {
                                            callbackQueueLabel = label
                                        }
                                    })

                                // This is to silence the warning about unused variables
                                _ = cancellable

                                expect(callbackQueueLabel).toEventually(equal(DispatchQueue.main.label))
                            }
                        }
                    }
                }
            }
        }
    }
}
#endif
