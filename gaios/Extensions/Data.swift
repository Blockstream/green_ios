import Foundation

extension Data {
    public var bytes: [UInt8] { [UInt8](self) }
    static func random(length: Int) throws -> Data {
        return Data((0..<length).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })
    }
}
