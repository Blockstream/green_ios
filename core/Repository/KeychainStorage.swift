import Foundation
import gdk
import greenaddress
import LocalAuthentication
import Security

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
            kSecAttrAccessGroup as String: Bundle.main.appGroup,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
    }

    func removeAll(_ query: [String: Any]? = nil) throws {
        let query = (query ?? self.query)
        let status = SecItemDelete(query as CFDictionary)
        try KeychainStorage.throwOSStatus(status)
    }

    private static func throwOSStatus(_ err: OSStatus) throws {
        guard err == errSecSuccess else {
            let text = SecCopyErrorMessageString(err, nil) ?? "" as CFString
            logger.error("Operation failed: \(err) \(text, privacy: .public))")
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
        }
    }

    func write(_ data: Data, from query: [String: Any]? = nil) throws {
        let query = (query ?? self.query)
        let queryRead = query.merging(
            [kSecMatchLimit as String: kSecMatchLimitOne, kSecReturnData as String: kCFBooleanTrue ?? true],
            uniquingKeysWith: {_, new in new})
        var retrivedData: CFTypeRef?
        let status = SecItemCopyMatching(queryRead as CFDictionary, &retrivedData)
        switch status {
        case errSecSuccess:
            let newAttributes = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, newAttributes as CFDictionary)
            try KeychainStorage.throwOSStatus(status)
        case errSecItemNotFound:
            var queryWrite = query
            queryWrite[kSecValueData as String] = data
            let status = SecItemAdd(queryWrite as CFDictionary, nil)
            try KeychainStorage.throwOSStatus(status)
        default:
            try KeychainStorage.throwOSStatus(status)
        }
    }

    func read(_ query: [String: Any]? = nil) throws -> Data? {
        let query = (query ?? self.query).merging(
            [kSecMatchLimit as String: kSecMatchLimitOne, kSecReturnData as String: kCFBooleanTrue ?? true], uniquingKeysWith: {_, new in new})
        var retrivedData: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &retrivedData)
        try KeychainStorage.throwOSStatus(status)
        return retrivedData as? Data
    }
}
