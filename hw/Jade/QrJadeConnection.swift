import Foundation
import SwiftCBOR
import Combine
import Semaphore

public protocol QRJadeResolver: AnyObject {
    func read() async throws -> Data
    func write(_ data: Data) async throws
}

public class QRJadeConnection: HWConnectionProtocol {
    
    public var qrJadeResolver: QRJadeResolver
    
    public init(qrJadeResolver: QRJadeResolver) {
        self.qrJadeResolver = qrJadeResolver
    }
    
    public func open() async throws {
        // nothing to do
    }
    
    public func exchange(_ data: Data) async throws -> Data {
        try await write(data)
        guard let res = try await read() else {
            throw HWError.Abort("No response")
        }
        return res
    }
    
    public func read() async throws -> Data? {
        try await qrJadeResolver.read()
    }
    
    public func write(_ data: Data) async throws {
        try await qrJadeResolver.write(data)
    }
    
    public func close() async throws {
        // nothing to do
    }
}
