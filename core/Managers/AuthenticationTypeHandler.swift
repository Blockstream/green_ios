import Foundation
import LocalAuthentication
import Security
import gdk
import core
import lightning

public class AuthenticationTypeHandler {
    public enum AuthError: Error, Equatable {
        case CanceledByUser
        case NotSupported
        case PasscodeNotSet
        case ConnectionFailed
        case KeychainError(_ status: OSStatus)
        case ServiceNotAvailable(_ desc: String)
        case SecurityError(_ desc: String)

        func description() -> String {
            localizedDescription
        }
        var localizedDescription: String {
            get {
                switch self {
                case .CanceledByUser:
                    return "id_action_canceled"
                case .NotSupported:
                    return "id_your_ios_device_might_not_be"
                case .PasscodeNotSet:
                    return "id_set_up_a_passcode_for_your_ios"
                case .ConnectionFailed:
                    return "id_connection_failed"
                case .KeychainError(let status):
                    if #available(iOS 11.3, *) {
                        let text = SecCopyErrorMessageString(status, nil) ?? "" as CFString
                        return "Operation failed: \(status) \(text))"
                    } else {
                        return "Operation failed: \(status). Check the error message through https://osstatus.com."
                    }
                case .ServiceNotAvailable(let desc), .SecurityError(let desc):
                    return desc
                }
            }
        }
    }

    public enum AuthType: String {
        case AuthKeyBiometric = "com.blockstream.green.auth_key_biometric"
        case AuthKeyPIN = "com.blockstream.green.auth_key_pin"
        case AuthKeyWOPassword = "com.blockstream.green.auth_key_wathonly_password"
        case AuthCertLightning = "com.blockstream.green.auth_key_lightning"
        case AuthKeyLightning = "com.blockstream.green.auth_key_credentials"
    }

    static let PrivateKeyPathSize = 32
    static let AuthKeyBiometricPrivateKeyPathPrefix = "com.blockstream.green."
    static let ECCEncryptionType = SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA256AESGCM
    static let ECCKeyType = kSecAttrKeyTypeECSECPrimeRandom
    static let ECCKeySizeInBits = 256

    public static var biometryType: LABiometryType? {
        let context = LAContext()

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        return context.biometryType
    }

    public static func supportsBiometricAuthentication() -> Bool {
        guard let biometryType = biometryType else {
            return false
        }
        return biometryType == LABiometryType.faceID || biometryType == LABiometryType.touchID
    }

    public static func supportsPasscodeAuthentication() -> Bool {
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    fileprivate static func describeKeychainError(_ status: OSStatus) -> OSStatus {
        if status != errSecSuccess && status != errSecDuplicateItem {
            if #available(iOS 11.3, *) {
                let err = SecCopyErrorMessageString(status, nil)
#if DEBUG
                logger.info("Operation failed: \(String(describing: err))")
#endif
            } else {
#if DEBUG
                logger.info("Operation failed: \(status). Check the error message through https://osstatus.com.")
#endif
            }
        }
        return status
    }

    fileprivate static func describeSecurityError(_ error: CFError) -> String {
        let err = CFErrorCopyDescription(error)
        let errorString = String(describing: err!)
#if DEBUG
        logger.info("Operation failed: \(errorString)")
#endif
        return errorString
    }

    fileprivate static func callWrapper(fun call: @autoclosure () -> Int32) -> OSStatus {
        return describeKeychainError(call())
    }

    fileprivate static func getACL() throws -> SecAccessControl {
        guard #available(iOS 11.3, *) else {
            throw AuthError.NotSupported
        }
        var error: Unmanaged<CFError>?
        let access = SecAccessControlCreateWithFlags(nil,
                                                     kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                     [SecAccessControlCreateFlags.biometryAny,
                                                      SecAccessControlCreateFlags.privateKeyUsage],
                                                     &error)
        guard error == nil else {
            throw AuthError.SecurityError(describeSecurityError(error!.takeRetainedValue()))
        }
        guard access != nil else {
            let text = "Operation failed: Access control not supported."
            throw AuthError.ServiceNotAvailable(text)
        }
        return access!
    }

    static func generateBiometricPrivateKey(network: String) throws {
        let acl = try getACL()

        let privateKeyLabel = AuthKeyBiometricPrivateKeyPathPrefix + String.random(length: PrivateKeyPathSize) + network
        let params: [CFString: Any] = [kSecAttrKeyType: ECCKeyType,
                                       kSecAttrKeySizeInBits: ECCKeySizeInBits,
                                       kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                                       kSecPrivateKeyAttrs: [kSecAttrLabel: privateKeyLabel,
                                                             kSecAttrAccessControl: acl,
                                                             kSecAttrIsPermanent: true]]

        var error: Unmanaged<CFError>?
        _ = SecKeyCreateRandomKey(params as CFDictionary, &error)
        guard error == nil else {
            throw AuthError.SecurityError(describeSecurityError(error!.takeRetainedValue()))
        }

        UserDefaults.standard.set(privateKeyLabel, forKey: "AuthKeyBiometricPrivateKey" + network)
    }

    fileprivate static func getPrivateKey(forNetwork: String) throws -> SecKey {
        let privateKeyLabel = UserDefaults.standard.string(forKey: "AuthKeyBiometricPrivateKey" + forNetwork)
        guard privateKeyLabel != nil else {
            throw AuthError.ServiceNotAvailable("Operation failed: Key not found.")
        }
        let q: [CFString: Any] = [kSecClass: kSecClassKey,
                                  kSecAttrKeyType: ECCKeyType,
                                  kSecAttrKeySizeInBits: ECCKeySizeInBits,
                                  kSecAttrLabel: privateKeyLabel!,
                                  kSecReturnRef: true,
                                  kSecUseOperationPrompt: "Unlock Green"]

        var privateKey: CFTypeRef?
        let status = callWrapper(fun: SecItemCopyMatching(q as CFDictionary, &privateKey))
        guard status == errSecSuccess else {
            throw AuthError.KeychainError(status)
        }
        // swiftlint:disable force_cast
        return privateKey as! SecKey
        // swiftlint:enable force_cast
    }

    fileprivate static func getPublicKey(forNetwork: String) throws -> SecKey {
        let privateKey = try getPrivateKey(forNetwork: forNetwork)
        guard let pubkey = SecKeyCopyPublicKey(privateKey) else {
            let text = "Operation failed: key does not contain a public key."
            throw AuthError.ServiceNotAvailable(text)
        }
        return pubkey
    }

    fileprivate static func decrypt(base64Encoded: Data, forNetwork: String) throws -> String {
        let privateKey = try getPrivateKey(forNetwork: forNetwork)

        let canDecrypt = SecKeyIsAlgorithmSupported(privateKey, SecKeyOperationType.decrypt, ECCEncryptionType)
        guard canDecrypt else {
            throw AuthError.ServiceNotAvailable("Operation failed: Decryption algorithm not supported.")
        }

        var error: Unmanaged<CFError>?
        let decrypted = SecKeyCreateDecryptedData(privateKey, ECCEncryptionType, base64Encoded as CFData, &error)
        guard error == nil else {
            let cfError = error!.takeRetainedValue()
            if CFErrorGetCode(cfError) == -2 {
                throw AuthError.CanceledByUser
            } else {
                throw AuthError.SecurityError(describeSecurityError(cfError))
            }
        }
        return String(data: decrypted! as Data, encoding: .utf8)!
    }

    fileprivate static func encrypt(plaintext: String, forNetwork: String) throws -> String {
        let publicKey = try getPublicKey(forNetwork: forNetwork)

        let canEncrypt = SecKeyIsAlgorithmSupported(publicKey, SecKeyOperationType.encrypt, ECCEncryptionType)
        guard canEncrypt else {
            throw AuthError.ServiceNotAvailable("Operation failed: Encryption algorithm not supported.")
        }

        var error: Unmanaged<CFError>?
        let data = plaintext.data(using: .utf8, allowLossyConversion: false)
        let encrypted = SecKeyCreateEncryptedData(publicKey, ECCEncryptionType, data! as CFData, &error)
        guard error == nil else {
            throw AuthError.SecurityError(describeSecurityError(error!.takeRetainedValue()))
        }

        return (encrypted! as Data).base64EncodedString()
    }

    fileprivate static func queryFor(method: AuthType, forNetwork: String, version: Int) -> [CFString: Any] {
        var q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: method.rawValue,
            kSecAttrAccount: forNetwork]
        if version == 0 {
            q[kSecAttrAccessible] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        } else if version == 1 {
            q[kSecAttrAccessGroup] = Bundle.main.appGroup
            switch method {
            case .AuthKeyBiometric:
                q[kSecAttrAccessible] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            case .AuthKeyLightning, .AuthCertLightning:
                q[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            case .AuthKeyPIN, .AuthKeyWOPassword:
                q[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
            }
        }
        return q
    }

    fileprivate static func queryForData(method: AuthType, forNetwork: String, version: Int) -> [CFString: Any] {
        return queryFor(method: method, forNetwork: forNetwork, version: version)
                        .merging([kSecReturnData: kCFBooleanTrue ?? true]) { (current, _) in current }
    }

    fileprivate static func set(method: AuthType, data: [String: Any], forNetwork: String) throws {
        if !supportsPasscodeAuthentication() {
            throw AuthError.PasscodeNotSet
        }
        guard let data = try? JSONSerialization.data(withJSONObject: data) else {
            throw AuthError.ServiceNotAvailable("Operation failed: Invalid json on serialization.")
        }
        let q = queryFor(method: method, forNetwork: forNetwork, version: 1)
        let qAdd = q.merging([kSecValueData: data]) { (current, _) in current }
        var status = callWrapper(fun: SecItemAdd(qAdd as CFDictionary, nil))
        if status == errSecDuplicateItem {
            status = callWrapper(fun: SecItemDelete(q as CFDictionary))
            status = callWrapper(fun: SecItemAdd(qAdd as CFDictionary, nil))
        }
        if status != errSecSuccess {
            throw AuthError.KeychainError(status)
        }
    }

    fileprivate static func get_(method: AuthType, forNetwork: String, version: Int = 1) throws -> [String: Any] {
        let q = queryForData(method: method, forNetwork: forNetwork, version: version)
        var result: CFTypeRef?
        let status = callWrapper(fun: SecItemCopyMatching(q as CFDictionary, &result))
        guard status == errSecSuccess, result != nil, let resultData = result as? Data else {
            throw AuthError.KeychainError(status)
        }
        guard let data = try? JSONSerialization.jsonObject(with: resultData, options: []) as? [String: Any] else {
            throw AuthError.ServiceNotAvailable("Operation failed: Invalid json on serialization.")
        }
        return data
    }

    fileprivate static func get(method: AuthType, toDecrypt: Bool, forNetwork: String) throws -> [String: Any] {
        var data = [String: Any]()
        do {
            data = try get_(method: method, forNetwork: forNetwork)
        } catch {
            data = try get_(method: method, forNetwork: forNetwork, version: 0)
        }
        if toDecrypt {
            precondition(method == AuthType.AuthKeyBiometric)
            let encryptedBiometric = data["encrypted_biometric"] as? String
            let decoded = Data(base64Encoded: encryptedBiometric!)
            let plaintext = try decrypt(base64Encoded: decoded!, forNetwork: forNetwork)
            data["plaintext_biometric"] = plaintext
        }
        return data
    }

    public static func getAuth(method: AuthType, forNetwork: String) throws -> PinData {
        let pinData = try get(method: method, toDecrypt: method == .AuthKeyBiometric, forNetwork: forNetwork)
        let jsonData = try JSONSerialization.data(withJSONObject: pinData)
        return try JSONDecoder().decode(PinData.self, from: jsonData)
    }

    public static func findAuth(method: AuthType, forNetwork: String) -> Bool {
        do {
            _ = try get_(method: method, forNetwork: forNetwork)
            return true
        } catch {
            return (try? get_(method: method, forNetwork: forNetwork, version: 0)) != nil
        }
    }

    public static func removePrivateKey(forNetwork: String) throws {
        let privateKeyLabel = UserDefaults.standard.string(forKey: "AuthKeyBiometricPrivateKey" + forNetwork)
        guard privateKeyLabel != nil else {
            throw AuthError.ServiceNotAvailable("Operation failed: Key not found.")
        }
        let q: [CFString: Any] = [kSecClass: kSecClassKey,
                                  kSecAttrKeyType: ECCKeyType,
                                  kSecAttrKeySizeInBits: ECCKeySizeInBits,
                                  kSecAttrLabel: privateKeyLabel!,
                                  kSecReturnRef: true]
        let status = callWrapper(fun: SecItemDelete(q as CFDictionary))
        if status != errSecSuccess {
            throw AuthError.KeychainError(status)
        }
    }

    public static func removeAuth(method: AuthType, forNetwork: String) -> Bool {
        let q0 = queryForData(method: method, forNetwork: forNetwork, version: 0)
        _ = callWrapper(fun: SecItemDelete(q0 as CFDictionary)) == errSecSuccess
        let q1 = queryForData(method: method, forNetwork: forNetwork, version: 1)
        return callWrapper(fun: SecItemDelete(q1 as CFDictionary)) == errSecSuccess
    }

    public static func addPIN(pinData: PinData, forNetwork: String) throws {
        try set(method: .AuthKeyPIN, data: pinData.toDict() ?? [:], forNetwork: forNetwork)
    }

    public static func addWatchonlyMultisig(password: String, forNetwork: String) throws {
        try set(method: .AuthKeyWOPassword, data: [:], forNetwork: forNetwork)
    }

    public static func addAuthKeyLightning(credentials: Credentials, forNetwork: String) throws {
        try set(method: .AuthKeyLightning, data: credentials.toDict() ?? [:], forNetwork: forNetwork)
    }

    public static func getAuthKeyLightning(forNetwork: String) throws -> Credentials {
        let data = try get(method: AuthType.AuthKeyLightning, toDecrypt: false, forNetwork: forNetwork)
        guard let credentials = Credentials.from(data) as? Credentials else {
            throw AuthError.SecurityError("Invalid credentials")
        }
        return credentials
    }

    public static func addBiometry(pinData: PinData, extraData: String, forNetwork: String) throws {
        let authKeyBiometricPrivateKey = UserDefaults.standard.string(forKey: "AuthKeyBiometricPrivateKey" + forNetwork)
        if authKeyBiometricPrivateKey == nil {
            try AuthenticationTypeHandler.generateBiometricPrivateKey(network: forNetwork)
        }
        let encrypted = try encrypt(plaintext: extraData, forNetwork: forNetwork)
        var pindata = pinData
        pindata.encryptedBiometric = encrypted
        try set(method: .AuthKeyBiometric, data: pindata.toDict() ?? [:], forNetwork: forNetwork)
    }

    public static func addCertLightning(forNetwork: String, credentials: AppGreenlightCredentials) throws {
        try set(method: .AuthCertLightning, data: credentials.toDict() ?? [:], forNetwork: forNetwork)
    }

    public static func getCertLightning(forNetwork: String) throws -> AppGreenlightCredentials {
        let type = AuthType.AuthCertLightning
        let data = try get(method: type, toDecrypt: false, forNetwork: forNetwork)
        guard let credentials = AppGreenlightCredentials.from(data) as? AppGreenlightCredentials else {
            throw AuthError.SecurityError("Invalid credentials")
        }
        return credentials
    }
}
