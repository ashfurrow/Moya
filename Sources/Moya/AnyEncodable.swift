import Foundation

struct AnyEncodable: Encodable {

    private let encodable: any Encodable

    public init(_ encodable: any Encodable) {
        self.encodable = encodable
    }

    func encode(to encoder: any Encoder) throws {
        try encodable.encode(to: encoder)
    }
}
