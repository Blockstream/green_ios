import Foundation
import Security

class KeychainHelper {
    static let AuthKeyBiometric = "com.blockstream.green.auth_key_biometric"
    static let AuthKeyPIN = "com.blockstream.green.auth_key_pin"

    // FIXME: these parameters will need to change for release
    static let AuthKeyBiometricPrivateKey = "com.blockstream.green.priv_key_biometric4"
    static let ECCEncryptionType = SecKeyAlgorithm.eciesEncryptionCofactorX963SHA256AESGCM
    static let ECCKeyType = kSecAttrKeyTypeECSECPrimeRandom
    static let ECCKeySizeInBits = 256

    fileprivate static func describeKeychainError(_ status: OSStatus) -> OSStatus {
        if status != errSecSuccess && status != errSecDuplicateItem {
            if #available(iOS 11.3, *) {
                let err = SecCopyErrorMessageString(status, nil)
                NSLog("Operation failed: \(String(describing: err))")
            } else {
                NSLog("Operation failed: \(status). Check the error message through https://osstatus.com.")
            }
        }
        return status
    }

    fileprivate static func callWrapper(fun call: @autoclosure () -> Int32) -> OSStatus {
        return describeKeychainError(call())
    }

    fileprivate static func getACL() -> SecAccessControl? {
        guard #available(iOS 11.3, *) else {
            return nil
        }
        var error: Unmanaged<CFError>?
        let access = SecAccessControlCreateWithFlags(nil,
                                                     kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                     [SecAccessControlCreateFlags.biometryCurrentSet,
                                                      SecAccessControlCreateFlags.privateKeyUsage],
                                                     &error);
        guard error == nil else {
            return nil
        }
        return access
    }

    public static func generatePrivateKey(network: String) -> Bool {
        let acl = getACL()
        guard acl != nil else {
            return false
        }
        let privateKeyLabel = AuthKeyBiometricPrivateKey + network
        let params: [CFString: Any] = [kSecAttrKeyType: ECCKeyType,
                                       kSecAttrKeySizeInBits: ECCKeySizeInBits,
                                       kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                                       kSecPrivateKeyAttrs: [kSecAttrLabel: privateKeyLabel,
                                                             kSecAttrAccessControl: acl!,
                                                             kSecAttrIsPermanent: true]]

        var error: Unmanaged<CFError>?
        _ = SecKeyCreateRandomKey(params as CFDictionary, &error)
        guard error == nil else {
            return false
        }
        return true
    }

    fileprivate static func getPrivateKey(forNetwork: String) -> SecKey? {
        let privateKeyLabel = AuthKeyBiometricPrivateKey + forNetwork
        let q: [CFString: Any] = [kSecClass: kSecClassKey,
                                  kSecAttrKeyType: ECCKeyType,
                                  kSecAttrKeySizeInBits: ECCKeySizeInBits,
                                  kSecAttrLabel: privateKeyLabel,
                                  kSecReturnRef: true,
                                  kSecUseOperationPrompt: "Unlock Green"]

        var privateKey: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &privateKey)
        guard status == errSecSuccess else {
            return nil
        }
        return (privateKey as! SecKey)
    }

    fileprivate static func getPublicKey(forNetwork: String) -> SecKey? {
        let privateKey = getPrivateKey(forNetwork: forNetwork)
        guard privateKey != nil else {
            return nil
        }
        return SecKeyCopyPublicKey(privateKey!)
    }

    fileprivate static func decrypt(base64Encoded: Data, forNetwork: String) -> String? {
        let privateKey = getPrivateKey(forNetwork: forNetwork)
        guard privateKey != nil else {
            return nil
        }

        let canDecrypt = SecKeyIsAlgorithmSupported(privateKey!, SecKeyOperationType.decrypt, ECCEncryptionType)
        guard canDecrypt else {
            return nil
        }

        var error: Unmanaged<CFError>?
        let decrypted = SecKeyCreateDecryptedData(privateKey!, ECCEncryptionType, base64Encoded as CFData, &error)
        guard error == nil else {
            let err = CFErrorCopyDescription(error!.takeRetainedValue())
            NSLog("Operation failed: \(String(describing: err))")
            return nil
        }
        return String(data: decrypted! as Data, encoding: .utf8)
    }

    fileprivate static func encrypt(plaintext: String, forNetwork: String) -> String? {
        let publicKey = getPublicKey(forNetwork: forNetwork)
        guard publicKey != nil else {
            return nil
        }

        var error: Unmanaged<CFError>?
        let canEncrypt = SecKeyIsAlgorithmSupported(publicKey! , SecKeyOperationType.encrypt, ECCEncryptionType)
        guard canEncrypt else {
            return nil
        }

        let data = plaintext.data(using: .utf8, allowLossyConversion: false)
        let encrypted = SecKeyCreateEncryptedData(publicKey!, ECCEncryptionType, data! as CFData, &error)
        guard error == nil else {
            let err = CFErrorCopyDescription(error!.takeRetainedValue())
            NSLog("Operation failed: \(String(describing: err))")
            return nil
        }

        return (encrypted! as Data).base64EncodedString()
    }

    fileprivate static func queryFor(method: String, forNetwork: String) -> [CFString: Any] {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                  kSecAttrAccessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                  kSecAttrService: method,
                                  kSecAttrAccount: forNetwork]
        return q
    }

    fileprivate static func queryForData(method: String, forNetwork: String) -> [CFString: Any] {
        return queryFor(method: method, forNetwork: forNetwork)
                        .merging([kSecReturnData: kCFBooleanTrue]) { (current, _) in current }
    }

    fileprivate static func set(method: String, data: [String: Any], forNetwork: String) -> OSStatus {
        let data = try? JSONSerialization.data(withJSONObject: data)
        guard data != nil else {
            return errSecServiceNotAvailable
        }
        let q = queryFor(method: method, forNetwork: forNetwork)
        let qAdd = q.merging([kSecValueData: data!]) { (current, _) in current }
        var status = callWrapper(fun: SecItemAdd(qAdd as CFDictionary, nil))
        if status == errSecDuplicateItem {
            status = callWrapper(fun: SecItemDelete(q as CFDictionary))
            status = callWrapper(fun: SecItemAdd(q as CFDictionary, nil))
        }
        return status
    }

    fileprivate static func get_(method: String, forNetwork: String) -> [String: Any]? {
        let q = queryForData(method: method, forNetwork: forNetwork)
        var result: CFTypeRef? = nil
        let status = callWrapper(fun: SecItemCopyMatching(q as CFDictionary, &result))
        guard status == errSecSuccess, result != nil else {
            return nil
        }
        let data = try? JSONSerialization.jsonObject(with: result as! Data, options: [])
        guard data != nil else {
            return nil
        }
        return (data! as! [String: Any])
    }

    fileprivate static func get(method: String, toDecrypt: Bool, forNetwork: String) -> [String: Any]? {
        guard let data = get_(method: method, forNetwork: forNetwork) else {
            return nil
        }
        var extended = data
        if toDecrypt && method == AuthKeyBiometric {
            guard let decoded = Data(base64Encoded: data["encrypted_biometric"] as! String),
                let plaintext = decrypt(base64Encoded: decoded, forNetwork: forNetwork) else {
                    return nil
            }
            extended["plaintext_biometric"] = plaintext
        }
        return extended
    }

    public static func getAuth(method: String, forNetwork: String) -> [String: Any]? {
        return get(method: method, toDecrypt: true, forNetwork: forNetwork)
    }

    public static func findAuth(method: String, forNetwork: String) -> Bool {
        return get_(method: method, forNetwork: forNetwork) != nil
    }

    public static func removeAuth(method: String, forNetwork: String) -> Bool {
        let q = queryForData(method: method, forNetwork: forNetwork)
        return callWrapper(fun: SecItemDelete(q as CFDictionary)) == errSecSuccess
    }

    public static func addBiometryType(data: [String: Any], extraData: String, forNetwork: String) -> Bool {
        guard let encrypted = encrypt(plaintext: extraData, forNetwork: forNetwork) else {
            return false
        }
        var extended = data
        extended["encrypted_biometric"] = encrypted
        let status = set(method: AuthKeyBiometric, data: extended, forNetwork: forNetwork)
        guard status == errSecSuccess else {
            return true
        }
        return false
    }

    public static func addPIN(data: [String: Any], forNetwork: String) -> Bool {
        let status = set(method: AuthKeyPIN, data: data, forNetwork: forNetwork)
        guard status == errSecSuccess else {
            return false
        }
        return true
    }
}
