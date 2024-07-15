import Quick
import Nimble
import RxSwift
import OHHTTPStubs

#if canImport(OHHTTPStubsSwift)
import OHHTTPStubsSwift
#endif

@testable import Moya
@testable import RxMoya

final class MoyaProviderRxSpec: QuickSpec {
    override func spec() {
        describe("provider with Single") {
            var provider: MoyaProvider<GitHub>!

            beforeEach {
                provider = MoyaProvider<GitHub>(stubClosure: MoyaProvider.immediatelyStub)
            }

            it("emits a Response object") {
                var called = false

                _ = provider.rx.request(.zen).subscribe { event in
                    switch event {
                    case .success:            called = true
                    case .failure(let error): fail("errored: \(error)")
                    }
                }

                expect(called).to(beTrue())
            }

            it("emits stubbed data for zen request") {
                var responseData: Data?

                let target: GitHub = .zen
                _ = provider.rx.request(target).subscribe { event in
                    switch event {
                    case .success(let response):    responseData = response.data
                    case .failure(let error):       fail("errored: \(error)")
                    }
                }

                expect(responseData).to(equal(target.sampleData))
            }

            it("maps JSON data correctly for user profile request") {
                var receivedResponse: [String: Any]?

                let target: GitHub = .userProfile("ashfurrow")
                _ = provider.rx.request(target).asObservable().mapJSON().subscribe(onNext: { response in
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

                _ = provider.rx.request(.zen).subscribe { event in
                    switch event {
                    case .success:            fail("should have errored")
                    case .failure(let error): receivedError = error as? MoyaError
                    }
                }

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
                _ = provider.rx.request(target).subscribe { event in
                    switch event {
                    case .success:  fail("we should have errored")
                    case .failure:  errored = true
                    }
                }

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
                let signalProducer1 = provider.rx.request(target)
                let signalProducer2 = provider.rx.request(target)

                expect(provider.inflightRequests.keys.count).to(equal(0))

                var receivedResponse: Moya.Response!

                _ = signalProducer1.subscribe { event in
                    switch event {
                    case .success(let response):
                        receivedResponse = response
                        expect(provider.inflightRequests.count).to(equal(1))

                    case .failure(let error):
                        fail("errored: \(error)")
                    }
                }

                _ = signalProducer2.subscribe { event in
                    switch event {
                    case .success(let response):
                        expect(receivedResponse).toNot(beNil())
                        expect(receivedResponse).to(beIdenticalToResponse(response))
                        expect(provider.inflightRequests.count).to(equal(1))

                    case .failure(let error):
                        fail("errored: \(error)")
                    }
                }

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

                _ = provider.rx.requestWithProgress(target)
                    .subscribe({ event in
                        switch event {
                        case let .next(element):
                            nextProgressValues.append(element.progress)

                            if element.response != nil { nextResponseCount += 1 }
                        case .error: errorEventsCount += 1
                        case .completed: completedEventsCount += 1
                        }
                    })

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
                    var disposeBag: DisposeBag!

                    beforeEach {
                        disposeBag = DisposeBag()

                        callbackQueue = DispatchQueue(label: UUID().uuidString)
                        provider = MoyaProvider<GitHub>(callbackQueue: callbackQueue)
                    }

                    context("the callback queue is provided with the request") {
                        it("invokes the callback on the request queue") {
                            let requestQueue = DispatchQueue(label: UUID().uuidString)
                            let callbackQueueLabel = Atomic<String?>(wrappedValue: nil)

                            waitUntil(action: { completion in
                                provider.rx.request(.zen, callbackQueue: requestQueue)
                                    .subscribe(onSuccess: { _ in
                                        callbackQueueLabel.wrappedValue = DispatchQueue.currentLabel
                                        completion()
                                    }).disposed(by: disposeBag)
                            })

                            expect(callbackQueueLabel.wrappedValue) == requestQueue.label
                        }
                    }

                    context("the queueless request method is invoked") {
                        it("invokes the callback on the provider queue") {
                            var callbackQueueLabel: String?

                            waitUntil(action: { completion in
                                provider.rx.request(.zen)
                                    .subscribe(onSuccess: { _ in
                                        callbackQueueLabel = DispatchQueue.currentLabel
                                        completion()
                                    }).disposed(by: disposeBag)
                            })

                            expect(callbackQueueLabel) == callbackQueue.label
                        }
                    }
                }

                describe("a provider without a predefined queue") {
                    var provider: MoyaProvider<GitHub>!
                    var disposeBag: DisposeBag!

                    beforeEach {
                        disposeBag = DisposeBag()
                        provider = MoyaProvider<GitHub>()
                    }

                    context("the queue is provided with the request") {
                        it("invokes the callback on the specified queue") {
                            let requestQueue = DispatchQueue(label: UUID().uuidString)
                            var callbackQueueLabel: String?

                            waitUntil(action: { completion in

                                provider.rx.request(.zen, callbackQueue: requestQueue)
                                    .subscribe(onSuccess: { _ in
                                        callbackQueueLabel = DispatchQueue.currentLabel
                                        completion()
                                    }).disposed(by: disposeBag)
                            })

                            expect(callbackQueueLabel) == requestQueue.label
                        }
                    }

                    context("the queue is not provided with the request") {
                        it("invokes the callback on the main queue") {
                            var callbackQueueLabel: String?

                            waitUntil(action: { completion in
                                provider.rx.request(.zen)
                                    .subscribe(onSuccess: { _ in
                                        callbackQueueLabel = DispatchQueue.currentLabel
                                        completion()
                                    }).disposed(by: disposeBag)
                            })

                            expect(callbackQueueLabel) == DispatchQueue.main.label
                        }
                    }
                }
            }
        }
    }
}
