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
