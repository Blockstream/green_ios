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
