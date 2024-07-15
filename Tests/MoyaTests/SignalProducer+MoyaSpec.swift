import Quick
import Moya
import ReactiveSwift
import Nimble
import Foundation

private func signalSendingData(_ data: Data, statusCode: Int = 200) -> SignalProducer<Response, MoyaError> {
    SignalProducer(value: Response(statusCode: statusCode, data: data as Data, response: nil))
}

final class SignalProducerMoyaSpec: QuickSpec {
    override func spec() {
        describe("status codes filtering") {
            it("filters out unrequested status codes closed range upperbound") {
                let data = Data()
                let signal = signalSendingData(data, statusCode: 10)

                var errored = false
                signal.filter(statusCodes: 0...9).startWithResult { event in
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
                let signal = signalSendingData(data, statusCode: -1)

                var errored = false
                signal.filter(statusCodes: 0...9).startWithResult { event in
                    switch event {
                    case .success(let object):
                        fail("called on non-correct status code: \(object)")
                    case .failure:
                        errored = true
                    }
                }

                expect(errored).to(beTruthy())
            }

            it("filters out unrequested status codes range upperbound") {
                let data = Data()
                let signal = signalSendingData(data, statusCode: 10)

                var errored = false
                signal.filter(statusCodes: 0..<10).startWithResult { event in
                    switch event {
                    case .success(let object):
                        fail("called on non-correct status code: \(object)")
                    case .failure:
                        errored = true
                    }
                }

                expect(errored).to(beTruthy())
            }

            it("filters out unrequested status codes range lowerbound") {
                let data = Data()
                let signal = signalSendingData(data, statusCode: -1)

                var errored = false
                signal.filter(statusCodes: 0..<10).startWithResult { event in
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
                let signal = signalSendingData(data, statusCode: 404)

                var errored = false
                signal.filterSuccessfulStatusCodes().startWithResult { result in
                    switch result {
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
                let signal = signalSendingData(data)

                var called = false
                signal.filterSuccessfulStatusCodes().startWithResult { _ in
                    called = true
                }

                expect(called).to(beTruthy())
            }

            it("filters out non-successful status and redirect codes") {
                let data = Data()
                let signal = signalSendingData(data, statusCode: 404)

                var errored = false
                signal.filterSuccessfulStatusAndRedirectCodes().startWithResult { result in
                    switch result {
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
                let signal = signalSendingData(data)

                var called = false
                signal.filterSuccessfulStatusAndRedirectCodes().startWithResult { _ in
                    called = true
                }

                expect(called).to(beTruthy())
            }

            it("passes through correct redirect codes") {
                let data = Data()
                let signal = signalSendingData(data, statusCode: 304)

                var called = false
                signal.filterSuccessfulStatusAndRedirectCodes().startWithResult { _ in
                    called = true
                }

                expect(called).to(beTruthy())
            }

            it("knows how to filter individual status codes") {
                let data = Data()
                let signal = signalSendingData(data, statusCode: 42)

                var called = false
                signal.filter(statusCode: 42).startWithResult { _ in
                    called = true
                }

                expect(called).to(beTruthy())
            }

            it("filters out different individual status code") {
                let data = Data()
                let signal = signalSendingData(data, statusCode: 43)

                var errored = false
                signal.filter(statusCode: 42).startWithResult { result in
                    switch result {
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
                let data = image.asJPEGRepresentation(0.75)
                let signal = signalSendingData(data!)

                var size: CGSize?
                signal.mapImage().startWithResult { _ in
                    size = image.size
                }

                expect(size).to(equal(image.size))
            }

            it("ignores invalid data") {
                let data = Data()
                let signal = signalSendingData(data)

                var receivedError: MoyaError?
                signal.mapImage().startWithResult { result in
                    switch result {
                    case .success:
                        fail("next called for invalid data")
                    case .failure(let error):
                        receivedError = error
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
                let data = try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                let signal = signalSendingData(data)

                var receivedJSON: [String: String]?
                signal.mapJSON().startWithResult { result in
                    if case .success(let response) = result,
                        let json = response as? [String: String] {
                        receivedJSON = json
                    }
                }

                expect(receivedJSON?["name"]).to(equal(json["name"]))
                expect(receivedJSON?["occupation"]).to(equal(json["occupation"]))
            }

            it("returns a Cocoa error domain for invalid JSON") {
                let json = "{ \"name\": \"john }"
                let data = json.data(using: String.Encoding.utf8)
                let signal = signalSendingData(data!)

                var receivedError: MoyaError?
                signal.mapJSON().startWithResult { result in
                    switch result {
                    case .success:
                        fail("next called for invalid data")
                    case .failure(let error):
                        receivedError = error
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
                let data = string.data(using: String.Encoding.utf8)
                let signal = signalSendingData(data!)

                var receivedString: String?
                signal.mapString().startWithResult { result in
                    receivedString = try? result.get()
                }

                expect(receivedString).to(equal(string))
            }

            it("maps data representing a string at a key path to a string") {
                let string = "You have the rights to the remains of a silent attorney."
                let json = ["words_to_live_by": string]
                let data = try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                let signal = signalSendingData(data)

                var receivedString: String?
                signal.mapString(atKeyPath: "words_to_live_by").startWithResult { result in
                    receivedString = try? result.get()
                }

                expect(receivedString).to(equal(string))
            }

            it("ignores invalid data") {
                let data = Data(bytes: [0x11FFFF] as [UInt32], count: 1) //Byte exceeding UTF8
                let signal = signalSendingData(data as Data)

                var receivedError: MoyaError?
                signal.mapString().startWithResult { result in
                    switch result {
                    case .success:
                        fail("next called for invalid data")
                    case .failure(let error):
                        receivedError = error
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
                let signal = signalSendingData(data)

                var receivedObject: Issue?
                _ = signal.map(Issue.self, using: decoder).startWithResult { result in
                    receivedObject = try? result.get()
                }
                expect(receivedObject).notTo(beNil())
                expect(receivedObject?.title) == "Hello, Moya!"
                expect(receivedObject?.createdAt) == formatter.date(from: "1995-01-14T12:34:56")!
            }

            it("maps data representing a json array to an array of decodable objects") {
                let jsonArray = [json, json, json]
                guard let data = try? JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted) else {
                    preconditionFailure("Failed creating Data from JSON dictionary")
                }
                let signal = signalSendingData(data)

                var receivedObjects: [Issue]?
                _ = signal.map([Issue].self, using: decoder).startWithResult { result in
                    receivedObjects = try? result.get()
                }
                expect(receivedObjects).notTo(beNil())
                expect(receivedObjects?.count) == 3
                expect(receivedObjects?.map { $0.title }) == ["Hello, Moya!", "Hello, Moya!", "Hello, Moya!"]
            }

            it("maps empty data to a decodable object with optional properties") {
                let signal = signalSendingData(Data())

                var receivedObjects: OptionalIssue?
                _ = signal.map(OptionalIssue.self, using: decoder, failsOnEmptyData: false).startWithResult { result in
                    receivedObjects = try? result.get()
                }
                expect(receivedObjects).notTo(beNil())
                expect(receivedObjects?.title).to(beNil())
                expect(receivedObjects?.createdAt).to(beNil())
            }

            it("maps empty data to a decodable array with optional properties") {
                let signal = signalSendingData(Data())

                var receivedObjects: [OptionalIssue]?
                _ = signal.map([OptionalIssue].self, using: decoder, failsOnEmptyData: false).startWithResult { result in
                    receivedObjects = try? result.get()
                }
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
                    let signal = signalSendingData(data)

                    var receivedObject: Issue?
                    _ = signal.map(Issue.self, atKeyPath: "issue", using: decoder).startWithResult { result in
                        receivedObject = try? result.get()
                    }
                    expect(receivedObject).notTo(beNil())
                    expect(receivedObject?.title) == "Hello, Moya!"
                    expect(receivedObject?.createdAt) == formatter.date(from: "1995-01-14T12:34:56")!
                }

                it("maps data representing a json array to a decodable object (#1311)") {
                    let json: [String: Any] = ["issues": [json]] // nested json array
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let signal = signalSendingData(data)

                    var receivedObjects: [Issue]?
                    _ = signal.map([Issue].self, atKeyPath: "issues", using: decoder).startWithResult { result in
                        receivedObjects = try? result.get()
                    }
                    expect(receivedObjects).notTo(beNil())
                    expect(receivedObjects?.count) == 1
                    expect(receivedObjects?.first?.title) == "Hello, Moya!"
                    expect(receivedObjects?.first?.createdAt) == formatter.date(from: "1995-01-14T12:34:56")!
                }

                it("maps empty data to a decodable object with optional properties") {
                    let signal = signalSendingData(Data())

                    var receivedObjects: OptionalIssue?
                    _ = signal.map(OptionalIssue.self, atKeyPath: "issue", using: decoder, failsOnEmptyData: false).startWithResult { result in
                        receivedObjects = try? result.get()
                    }
                    expect(receivedObjects).notTo(beNil())
                    expect(receivedObjects?.title).to(beNil())
                    expect(receivedObjects?.createdAt).to(beNil())
                }

                it("maps empty data to a decodable array with optional properties") {
                    let signal = signalSendingData(Data())

                    var receivedObjects: [OptionalIssue]?
                    _ = signal.map([OptionalIssue].self, atKeyPath: "issue", using: decoder, failsOnEmptyData: false).startWithResult { result in
                        receivedObjects = try? result.get()
                    }
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
                    let signal = signalSendingData(data)

                    var count: Int?
                    _ = signal.map(Int.self, atKeyPath: "count", using: decoder).startWithResult { result in
                        count = try? result.get()
                    }
                    expect(count).notTo(beNil())
                    expect(count) == 1
                }

                it("map Bool data to a Bool value") {
                    let json: [String: Any] = ["isNew": true]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let signal = signalSendingData(data)

                    var isNew: Bool?
                    _ = signal.map(Bool.self, atKeyPath: "isNew", using: decoder).startWithResult { result in
                        isNew = try? result.get()
                    }
                    expect(isNew).notTo(beNil())
                    expect(isNew) == true
                }

                it("map String data to a String value") {
                    let json: [String: Any] = ["description": "Something interesting"]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let signal = signalSendingData(data)

                    var description: String?
                    _ = signal.map(String.self, atKeyPath: "description", using: decoder).startWithResult { result in
                        description = try? result.get()
                    }
                    expect(description).notTo(beNil())
                    expect(description) == "Something interesting"
                }

                it("map String data to a URL value") {
                    let json: [String: Any] = ["url": "http://www.example.com/test"]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let signal = signalSendingData(data)

                    var url: URL?
                    _ = signal.map(URL.self, atKeyPath: "url", using: decoder).startWithResult { result in
                        url = try? result.get()
                    }
                    expect(url).notTo(beNil())
                    expect(url) == URL(string: "http://www.example.com/test")
                }

                it("shouldn't map Int data to a Bool value") {
                    let json: [String: Any] = ["isNew": 1]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let signal = signalSendingData(data)

                    var isNew: Bool?
                    _ = signal.map(Bool.self, atKeyPath: "isNew", using: decoder).startWithResult { result in
                        isNew = try? result.get()
                    }
                    expect(isNew).to(beNil())
                }

                it("shouldn't map String data to an Int value") {
                    let json: [String: Any] = ["test": "123"]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let signal = signalSendingData(data)

                    var test: Int?
                    _ = signal.map(Int.self, atKeyPath: "test", using: decoder).startWithResult { result in
                        test = try? result.get()
                    }
                    expect(test).to(beNil())
                }

                it("shouldn't map Array<String> data to an String value") {
                    let json: [String: Any] = ["test": ["123", "456"]]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let signal = signalSendingData(data)

                    var test: String?
                    _ = signal.map(String.self, atKeyPath: "test", using: decoder).startWithResult { result in
                        test = try? result.get()
                    }
                    expect(test).to(beNil())
                }

                it("shouldn't map String data to an Array<String> value") {
                    let json: [String: Any] = ["test": "123"]
                    guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                        preconditionFailure("Failed creating Data from JSON dictionary")
                    }
                    let signal = signalSendingData(data)

                    var test: [String]?
                    _ = signal.map([String].self, atKeyPath: "test", using: decoder).startWithResult { result in
                        test = try? result.get()
                    }
                    expect(test).to(beNil())
                }
            }
            it("ignores invalid data") {
                var json = json
                json["createdAt"] = "Hahaha" // invalid date string
                guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
                    preconditionFailure("Failed creating Data from JSON dictionary")
                }
                let signal = signalSendingData(data)

                var receivedError: (any Error)?
                _ = signal.map(Issue.self, using: decoder).startWithResult { result in
                    switch result {
                    case .success:
                        fail("next called for invalid data")
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
