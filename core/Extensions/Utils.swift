import Foundation

public typealias VoidToVoid = () -> Void

public func secureRandomData(count: Int) -> Data? {
    var bytes = [Int8](repeating: 0, count: count)
    let status = SecRandomCopyBytes(
        kSecRandomDefault,
        count,
        &bytes
    )
    if status == errSecSuccess {
        return Data(bytes: bytes, count: count)
    }
    return nil
}

public extension Dictionary {

    func stringify() -> String? {
        if let data = try? JSONSerialization.data(withJSONObject: self, options: .fragmentsAllowed) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}

extension UInt {
    func uint32BE() -> [UInt8] {
        return [UInt8((self >> 24) & 0xff), UInt8((self >> 16) & 0xff),
                UInt8((self >> 8) & 0xff), UInt8(self & 0xff)]
    }

    func uint32LE() -> [UInt8] {
        return [UInt8(self & 0xff), UInt8((self >> 8) & 0xff),
                UInt8((self >> 16) & 0xff), UInt8((self >> 24) & 0xff)]
    }

    func varint() -> [UInt8] {
        if self < 0xfd {
            return [UInt8(self & 0xff)]
        } else if self <= 0xffff {
            return [UInt8(0xfd), UInt8(self & 0xff), UInt8((self >> 8) & 0xff)]
        } else {
            return [UInt8(0xfe)] + self.uint32LE()
        }
    }
}

extension Int {
    func varInt() -> [UInt8] {
        switch varIntSize() {
        case 1:
            return [UInt8(self)]
        case 3:
            return [253, UInt8(self & 0xff), UInt8((self >> 8) & 0xff)]
        case 5:
            return [254] + UInt(self).uint32LE()
        default:
            return [255] + UInt64(self).uint64LE()
        }
    }

    func varIntSize() -> UInt8 {
        // if negative, it's actually a very large unsigned long value
        if self < 0 { return 9 } // 1 marker + 8 data bytes
        if self < 253 { return 1 } // 1 data byte
        if self <= 0xFFFF { return 3 } // 1 marker + 2 data bytes
        if self <= 0xFFFFFFFF { return 5 } // 1 marker + 4 data bytes
        return 9 // 1 marker + 8 data bytes
    }
}

extension UInt64 {
    func uint64LE() -> [UInt8] {
        return [UInt8(self & 0xff), UInt8((self >> 8) & 0xff),
                UInt8((self >> 16) & 0xff), UInt8((self >> 24) & 0xff),
                UInt8((self >> 32) & 0xff), UInt8((self >> 40) & 0xff),
                UInt8((self >> 48) & 0xff), UInt8((self >> 56) & 0xff)]
    }
    func int64() -> Int64 {
        return Int64(self)
    }
}
extension Optional where Wrapped == UInt64 {
    func int64() -> Int64? {
        if let uint64 = self {
            return Int64(uint64)
        } else {
            return nil
        }
    }
}
extension String {
    var hexToData: Data? {
        data(using: .utf8)
    }
    var hexToDataReversed: Data? {
        guard let data = data(using: .utf8)?.reversed() else {
            return nil
        }
        return Data(data)
    }
}

extension Optional where Wrapped == String {
    var hexToData: Data? {
        self?.hexToData()
    }
    var hexToDataReversed: Data? {
        self?.hexToDataReversed
    }
}

extension Optional where Wrapped == Array<Any> {
    public var isNilOrEmpty: Bool {
        if let strongSelf = self, !strongSelf.isEmpty {
            return false
        }
        return true
    }
    public var isNotEmpty: Bool {
        return !isNilOrEmpty
    }
}

extension Optional where Wrapped == Array<String> {
    public var isNilOrEmpty: Bool {
        if let strongSelf = self, !strongSelf.isEmpty {
            return false
        }
        return true
    }
    public var isNotEmpty: Bool {
        return !isNilOrEmpty
    }
}
