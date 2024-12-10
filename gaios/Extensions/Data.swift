import Foundation

extension Data {
    static func random(length: Int) throws -> Data {
        return Data((0..<length).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })
    }
}
