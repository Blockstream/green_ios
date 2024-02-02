import Foundation

typealias VoidToVoid = () -> Void

func secureRandomData(count: Int) -> Data? {
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
