import Quick
import Moya
import RxSwift
import Nimble
import Foundation

final class SingleMoyaSpec: QuickSpec {
    override func spec() {
        describe("status codes filtering") {
            it("filters out unrequested status codes closed range upperbound") {
                let data = Data()
                let single = Response(statusCode: 10, data: data).asSingle()

                var errored = false
                _ = single.filter(statusCodes: 0...9).subscribe { event in
                    switch event {
                    case .success(let object):
                        fail("called on non-correct status code: \(object)")
                    case .failure:
                        errored = true
                    }
                }

                expect(errored).to(beTruthy())
            }

            it("filters out unrequested status codes closed range lowerbound") {
                let data = Data()
                let single = Response(statusCode: -1, data: data).asSingle()

                var errored = false
                _ = single.filter(statusCodes: 0...9).subscribe { event in
                    switch event {
                    case .success(let object):
                        fail("called on non-correct status code: \(object)")
                    case .failure:
                        errored = true
                    }
                }

                expect(errored).to(beTruthy())
            }

            it("filters out unrequested status codes with range upperbound") {
                let data = Data()
                let single = Response(statusCode: 10, data: data).asSingle()

                var errored = false
                _ = single.filter(statusCodes: 0..<10).subscribe { event in
                    switch event {
                    case .success(let object):
                        fail("called on non-correct status code: \(object)")
                    case .failure:
                        errored = true
                    }
                }

                expect(errored).to(beTruthy())
            }

            it("filters out unrequested status codes with range lowerbound") {
                let data = Data()
                let single = Response(statusCode: -1, data: data).asSingle()

                var errored = false
                _ = single.filter(statusCodes: 0..<10).subscribe { event in
                    switch event {
                    case .success(let object):
                        fail("called on non-correct status code: \(object)")
                    case .failure:
                        errored = true
                    }
                }

                expect(errored).to(beTruthy())
            }

            it("filters out non-successful status codes") {
                let data = Data()
                let single = Response(statusCode: 404, data: data).asSingle()

                var errored = false
                _ = single.filterSuccessfulStatusCodes().subscribe { event in
                    switch event {
                    case .success(let object):
                        fail("called on non-success status code: \(object)")
                    case .failure:
                        errored = true
                    }
                }

                expect(errored).to(beTruthy())
            }

            it("passes through correct status codes") {
                let data = Data()
                let single = Response(statusCode: 200, data: data).asSingle()

                var called = false
                _ = single.filterSuccessfulStatusCodes().subscribe(onSuccess: { _ in
                    called = true
                })

                expect(called).to(beTruthy())
            }

            it("filters out non-successful status and redirect codes") {
                let data = Data()
                let single = Response(statusCode: 404, data: data).asSingle()

                var errored = false
                _ = single.filterSuccessfulStatusAndRedirectCodes().subscribe { event in
                    switch event {
                    case .success(let object):
                        fail("called on non-success status code: \(object)")
                    case .failure:
                        errored = true
                    }
                }

                expect(errored).to(beTruthy())
            }

            it("passes through correct status codes") {
                let data = Data()
                let single = Response(statusCode: 200, data: data).asSingle()

                var called = false
                _ = single.filterSuccessfulStatusAndRedirectCodes().subscribe(onSuccess: { _ in
                    called = true
                })

                expect(called).to(beTruthy())
            }

            it("passes through correct redirect codes") {
                let data = Data()
                let single = Response(statusCode: 304, data: data).asSingle()

                var called = false
                _ = single.filterSuccessfulStatusAndRedirectCodes().subscribe(onSuccess: { _ in
                    called = true
                })

                expect(called).to(beTruthy())
            }

            it("knows how to filter individual status code") {
                let data = Data()
                let single = Response(statusCode: 42, data: data).asSingle()

                var called = false
                _ = single.filter(statusCode: 42).subscribe(onSuccess: { _ in
                    called = true
                })

                expect(called).to(beTruthy())
            }

            it("filters out different individual status code") {
                let data = Data()
                let single = Response(statusCode: 43, data: data).asSingle()

                var errored = false
                _ = single.filter(statusCode: 42).subscribe { event in
                    switch event {
                    case .success(let object):
                        fail("called on non-success status code: \(object)")
                    case .failure:
                        errored = true
                    }
                }

                expect(errored).to(beTruthy())
            }
        }

        describe("image maping") {
            it("maps data representing an image to an image") {
                let image = Image.testImage
                guard let data = image.asJPEGRepresentation(0.75) else {
                    fatalError("Failed creating Data from Image")
                }

                let single = Response(statusCode: 200, data: data).asSingle()

                var size: CGSize?
                _ = single.mapImage().subscribe(onSuccess: { image in
                    size = image.size
                })

                expect(size).to(equal(image.size))
            }

            it("ignores invalid data") {
                let data = Data()
                let single = Response(statusCode: 200, data: data).asSingle()

                var receivedError: MoyaError?
                _ = single.mapImage().subscribe { event in
                    switch event {
                    case .success:
                        fail("next called for invalid data")
                    case .failure(let error):
                        receivedError = error as? MoyaError
                    }
                }

                expect(receivedError).toNot(beNil())
                let expectedError = MoyaError.imageMapping(Response(statusCode: 200, data: Data(), response: nil))
                expect(receivedError).to(beOfSameErrorType(expectedError))
            }
        }

        describe("JSON mapping") {
            it("maps data representing some JSON to that JSON") {
                let json = ["name": "John Crighton", "occupation": "Astronaut"]
                guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                    fatalError("Failed creating Data from JSON dictionary")
                }

                let single = Response(statusCode: 200, data: data).asSingle()

                var receivedJSON: [String: String]?
                _ = single.mapJSON().subscribe(onSuccess: { json in
                    if let json = json as? [String: String] {
                        receivedJSON = json
                    }
                })

                expect(receivedJSON?["name"]).to(equal(json["name"]))
                expect(receivedJSON?["occupation"]).to(equal(json["occupation"]))
            }

            it("returns a Cocoa error domain for invalid JSON") {
                let json = "{ \"name\": \"john }"
                guard let data = json.data(using: .utf8) else {
                    fatalError("Failed creating Data from JSON String")
                }

                let single = Response(statusCode: 200, data: data).asSingle()

                var receivedError: MoyaError?
                _ = single.mapJSON().subscribe { event in
                    switch event {
                    case .success:
                        fail("next called for invalid data")
                    case .failure(let error):
                        receivedError = error as? MoyaError
                    }
                }

                expect(receivedError).toNot(beNil())
                switch receivedError {
                case .some(.jsonMapping):
                    break
                default:
                    fail("expected NSError with \(NSCocoaErrorDomain) domain")
                }
            }
        }

        describe("string mapping") {
            it("maps data representing a string to a string") {
                let string = "You have the rights to the remains of a silent attorney."
                guard let data = string.data(using: .utf8) else {
                    fatalError("Failed creating Data from String")
                }

                let single = Response(statusCode: 200, data: data).asSingle()

                var receivedString: String?
                _ = single.mapString().subscribe(onSuccess: { string in
                    receivedString = string
                })

                expect(receivedString).to(equal(string))
            }

            it("maps data representing a string at a key path to a string") {
                let string = "You have the rights to the remains of a silent attorney."
                let json = ["words_to_live_by": string]
                guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                    fatalError("Failed creating Data from JSON dictionary")
                }

                let single = Response(statusCode: 200, data: data).asSingle()

                var receivedString: String?
                _ = single.mapString(atKeyPath: "words_to_live_by").subscribe(onSuccess: { string in
                    receivedString = string
                })

                expect(receivedString).to(equal(string))
            }

            it("ignores invalid data") {
                let data = Data(bytes: [0x11FFFF] as [UInt32], count: 1) //Byte exceeding UTF8
                let single = Response(statusCode: 200, data: data).asSingle()

                var receivedError: MoyaError?
                _ = single.mapString().subscribe { event in
                    switch event {
                    case .success:
                        fail("next called for invalid data")
                    case .failure(let error):
                        receivedError = error as? MoyaError
                    }
                }

                expect(receivedError).toNot(beNil())
                let expectedError = MoyaError.stringMapping(Response(statusCode: 200, data: Data(), response: nil))
                expect(receivedError).to(beOfSameErrorType(expectedError))
            }
        }

        describe("object mapping") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(formatter)

            let json: [String: Any] = [
                "title": "Hello, Moya!",
                "createdAt": "1995-01-14T12:34:56"
            ]

            it("maps data representing a json to a decodable object") {
                guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                    preconditionFailure("Failed creating Data from JSON dictionary")
                }
                let single = Response(statusCode: 200, data: data).asSingle()

                var receivedObject: Issue?
                _ = single.map(Issue.self, using: decoder).subscribe(onSuccess: { object in
                    receivedObject = object
                })
                expect(receivedObject).notTo(beNil())
                expect(receivedObject?.title) == "Hello, Moya!"
                expect(receivedObject?.createdAt) == formatter.date(from: "1995-01-14T12:34:56")!
            }

            it("maps data representing a json array to an array of decodable objects") {
                let jsonArray = [json, json, json]
                guard let data = try? JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted) else {
                    preconditionFailure("Failed creating Data from JSON dictionary")
                }
                let single = Response(statusCode: 200, data: data).asSingle()

                var receivedObjects: [Issue]?
                _ = single.map([Issue].self, using: decoder).subscribe(onSuccess: { objects in
                    receivedObjects = objects
                })
                expect(receivedObjects).notTo(beNil())
                expect(receivedObjects?.count) == 3
                expect(receivedObjects?.map { $0.title }) == ["Hello, Moya!", "Hello, Moya!", "Hello, Moya!"]
            }

            it("maps empty data to a decodable object with optional properties") {
                let single = Response(statusCode: 200, data: Data()).asSingle()

                var receivedObjects: OptionalIssue?
                _ = single.map(OptionalIssue.self, using: decoder, failsOnEmptyData: false).subscribe(onSuccess: { object in
                    receivedObjects = object
                })
                expect(receivedObjects).notTo(beNil())
                expect(receivedObjects?.title).to(beNil())
                expect(receivedObjects?.createdAt).to(beNil())
            }

            it("maps empty data to a decodable array with optional properties") {
                let single = Response(statusCode: 200, data: Data()).asSingle()

                var receivedObjects: [OptionalIssue]?
                _ = single.map([OptionalIssue].self, using: decoder, failsOnEmptyData: false).subscribe(onSuccess: { object in
                    receivedObjects = object
                })
                expect(receivedObjects).notTo(beNil())
                expect(receivedObjects?.count) == 1
                expect(receivedObjects?.first?.title).to(beNil())
                expect(receivedObjects?.first?.createdAt).to(beNil())
            }

            context("when using key path mapping") {
                it("maps data representing a json to a decodable object") {
                    let json: [String: Any] = ["issue": json] // nested json
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let single = Response(statusCode: 200, data: data).asSingle()

                    var receivedObject: Issue?
                    _ = single.map(Issue.self, atKeyPath: "issue", using: decoder).subscribe(onSuccess: { object in
                        receivedObject = object
                    })
                    expect(receivedObject).notTo(beNil())
                    expect(receivedObject?.title) == "Hello, Moya!"
                    expect(receivedObject?.createdAt) == formatter.date(from: "1995-01-14T12:34:56")!
                }

                it("maps data representing a json array to a decodable object (#1311)") {
                    let json: [String: Any] = ["issues": [json]] // nested json array
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let single = Response(statusCode: 200, data: data).asSingle()

                    var receivedObjects: [Issue]?
                    _ = single.map([Issue].self, atKeyPath: "issues", using: decoder).subscribe(onSuccess: { object in
                        receivedObjects = object
                    })
                    expect(receivedObjects).notTo(beNil())
                    expect(receivedObjects?.count) == 1
                    expect(receivedObjects?.first?.title) == "Hello, Moya!"
                    expect(receivedObjects?.first?.createdAt) == formatter.date(from: "1995-01-14T12:34:56")!
                }

                it("maps empty data to a decodable object with optional properties") {
                    let single = Response(statusCode: 200, data: Data()).asSingle()

                    var receivedObjects: OptionalIssue?
                    _ = single.map(OptionalIssue.self, atKeyPath: "issue", using: decoder, failsOnEmptyData: false).subscribe(onSuccess: { object in
                        receivedObjects = object
                    })
                    expect(receivedObjects).notTo(beNil())
                    expect(receivedObjects?.title).to(beNil())
                    expect(receivedObjects?.createdAt).to(beNil())
                }

                it("maps empty data to a decodable array with optional properties") {
                    let single = Response(statusCode: 200, data: Data()).asSingle()

                    var receivedObjects: [OptionalIssue]?
                    _ = single.map([OptionalIssue].self, atKeyPath: "issue", using: decoder, failsOnEmptyData: false).subscribe(onSuccess: { object in
                        receivedObjects = object
                    })
                    expect(receivedObjects).notTo(beNil())
                    expect(receivedObjects?.count) == 1
                    expect(receivedObjects?.first?.title).to(beNil())
                    expect(receivedObjects?.first?.createdAt).to(beNil())
                }

                it("map Int data to an Int value") {
                    let json: [String: Any] = ["count": 1]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let observable = Response(statusCode: 200, data: data).asSingle()

                    var count: Int?
                    _ = observable.map(Int.self, atKeyPath: "count", using: decoder).subscribe(onSuccess: { value in
                        count = value
                    })
                    expect(count).notTo(beNil())
                    expect(count) == 1
                }

                it("map Bool data to a Bool value") {
                    let json: [String: Any] = ["isNew": true]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let observable = Response(statusCode: 200, data: data).asSingle()

                    var isNew: Bool?
                    _ = observable.map(Bool.self, atKeyPath: "isNew", using: decoder).subscribe(onSuccess: { value in
                        isNew = value
                    })
                    expect(isNew).notTo(beNil())
                    expect(isNew) == true
                }

                it("map String data to a String value") {
                    let json: [String: Any] = ["description": "Something interesting"]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let observable = Response(statusCode: 200, data: data).asSingle()

                    var description: String?
                    _ = observable.map(String.self, atKeyPath: "description", using: decoder).subscribe(onSuccess: { value in
                        description = value
                    })
                    expect(description).notTo(beNil())
                    expect(description) == "Something interesting"
                }

                it("map String data to a URL value") {
                    let json: [String: Any] = ["url": "http://www.example.com/test"]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let observable = Response(statusCode: 200, data: data).asSingle()

                    var url: URL?
                    _ = observable.map(URL.self, atKeyPath: "url", using: decoder).subscribe(onSuccess: { value in
                        url = value
                    })
                    expect(url).notTo(beNil())
                    expect(url) == URL(string: "http://www.example.com/test")
                }

                it("shouldn't map Int data to a Bool value") {
                    let json: [String: Any] = ["isNew": 1]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let observable = Response(statusCode: 200, data: data).asSingle()

                    var isNew: Bool?
                    _ = observable.map(Bool.self, atKeyPath: "isNew", using: decoder).subscribe(onSuccess: { value in
                        isNew = value
                    })
                    expect(isNew).to(beNil())
                }

                it("shouldn't map String data to an Int value") {
                    let json: [String: Any] = ["test": "123"]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let observable = Response(statusCode: 200, data: data).asSingle()

                    var test: Int?
                    _ = observable.map(Int.self, atKeyPath: "test", using: decoder).subscribe(onSuccess: { value in
                        test = value
                    })
                    expect(test).to(beNil())
                }

                it("shouldn't map Array<String> data to an String value") {
                    let json: [String: Any] = ["test": ["123", "456"]]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let observable = Response(statusCode: 200, data: data).asSingle()

                    var test: String?
                    _ = observable.map(String.self, atKeyPath: "test", using: decoder).subscribe(onSuccess: { value in
                        test = value
                    })
                    expect(test).to(beNil())
                }

                it("shouldn't map String data to an Array<String> value") {
                    let json: [String: Any] = ["test": "123"]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let observable = Response(statusCode: 200, data: data).asSingle()

                    var test: [String]?
                    _ = observable.map([String].self, atKeyPath: "test", using: decoder).subscribe(onSuccess: { value in
                        test = value
                    })
                    expect(test).to(beNil())
                }
            }
            it("ignores invalid data") {
                var json = json
                json["createdAt"] = "Hahaha" // invalid date string
                guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                    preconditionFailure("Failed creating Data from JSON dictionary")
                }
                let single = Response(statusCode: 200, data: data).asSingle()

                var receivedError: (any Error)?
                _ = single.map(Issue.self, using: decoder).subscribe { event in
                    switch event {
                    case .success:
                        fail("success called for invalid data")
                    case .failure(let error):
                        receivedError = error
                    }
                }

                if case let MoyaError.objectMapping(nestedError, _)? = receivedError {
                    expect(nestedError).to(beAKindOf(DecodingError.self))
                } else {
                    fail("expected <MoyaError.objectMapping>, got <\(String(describing: receivedError))>")
                }
            }
        }
    }
}
