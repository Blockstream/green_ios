import Foundation
import gdk
import greenaddress

public class KeychainStorage {

    let attrAccount: String
    let attrService: String
    let query: [String: Any]

    init(account: String, service: String) {
        attrAccount = account
        attrService = service
        query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: attrAccount,
            kSecAttrService as String: attrService,
            kSecAttrAccessGroup as String: Bundle.main.appGroup]
    }

    func removeAll() throws {
        let query = query.merging(
            [kSecMatchLimit as String: kSecMatchLimitOne, kSecReturnData as String: kCFBooleanTrue ?? true],
            uniquingKeysWith: {_, new in new})
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else {
            throw GaError.GenericError()
        }
    }

    func write(_ data: Data) throws {
        let query = query.merging(
            [kSecValueData as String: data],
            uniquingKeysWith: {_, new in new})
        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = SecItemDelete(query as CFDictionary)
            status = SecItemAdd(query as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            let text = SecCopyErrorMessageString(status, nil) ?? "" as CFString
            print("Operation failed: \(status) \(text))")
            throw GaError.GenericError()
        }
    }

    func read() throws -> Data {
        let query = query.merging(
            [kSecMatchLimit as String: kSecMatchLimitOne, kSecReturnData as String: kCFBooleanTrue ?? true],
            uniquingKeysWith: {_, new in new})
        var retrivedData: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &retrivedData)
        guard status == errSecSuccess else {
            let text = SecCopyErrorMessageString(status, nil) ?? "" as CFString
            print("Operation failed: \(status) \(text))")
            throw GaError.GenericError()
        }
        guard let data = retrivedData as? Data else { throw GaError.GenericError() }
        return data
    }
}
