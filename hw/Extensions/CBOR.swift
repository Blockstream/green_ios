import Foundation
import SwiftCBOR

extension CBOR {
    static func getDictionary (map: CBOR) -> [CBOR:CBOR]? {
        var extractedDict = [CBOR:CBOR]()
        switch map {
        case .map(let dict): extractedDict = dict
        default: break
        }
        return extractedDict
    }
    static func convertCBORMapToDictionary(_ cborMap: [CBOR: CBOR]) throws -> [String: Any?] {
        var result = [String: Any?]()
        for pair in cborMap {
            guard case let .utf8String(str) = pair.key else {
                fatalError("Non-String key in CBOR document: \(cborMap)")
            }
            result[str] = try convertToAny(pair.value)
        }
        return result
    }

    static func convertCBORMapToDictionary<T>(_ cborMap: [CBOR: CBOR]) throws -> [String: T?] {
        var result = [String: T?]()
        for pair in cborMap {
            guard case let .utf8String(str) = pair.key else {
                fatalError("Non-String key in CBOR document: \(cborMap)")
            }
            result[str] = try convertTo(pair.value)
        }
        return result
    }

    static func convertToAny(_ val: CBOR) throws -> Any? {
        return try convertTo(val)
    }

    static func convertTo<T>(_ val: CBOR) throws -> T? {
        switch val {
        case .boolean(let inner):
            return inner as? T
        case .unsignedInt(let inner):
            return Int(inner) as? T
        case .negativeInt(let inner):
            return -Int(inner) - 1 as? T
        case .double(let inner):
            return inner as? T
        case .float(let inner):
            return inner as? T
        case .half(let inner):
            return inner as? T
        case .simple(let inner):
            return inner as? T
        case .byteString(let inner):
            return inner as? T
        case .null:
            return nil as T?
        case .undefined:
            return nil as T?
        case .date(let inner):
            return inner as? T
        case .utf8String(let inner):
            return inner as? T
        case .array(let innerArr):
            return try innerArr.map(convertToAny) as? T
        case .map(let innerMap):
            return try convertCBORMapToDictionary(innerMap) as? T
        default:
            return nil as T?
        }
    }
}
