import Foundation
import LocalAuthentication
import Security
import gdk
import lightning

public class AuthenticationTypeHandler {
    public enum AuthError: Error, Equatable {
        case CanceledByUser
        case DeniedByUser
        case LockedOut
        case NotSupported
        case PasscodeNotSet
        case KeychainError(_ action: String, _ status: OSStatus)
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
                case .KeychainError(let action, let status):
                    let text = SecCopyErrorMessageString(status, nil) ?? "" as CFString
                    return "Operation \(action) fail: \(status) \(text))"
                case .ServiceNotAvailable(let desc), .SecurityError(let desc):
                    return desc
                case .DeniedByUser:
                    return "Denied by user"
                case .LockedOut:
                    return "Locked Out"
                }
            }
        }
    }

    public enum AuthType: String {
        case AuthKeyBiometric = "com.blockstream.green.auth_key_biometric" // for PinData
        case AuthKeyPIN = "com.blockstream.green.auth_key_pin" // for PinData
        case AuthCertLightning = "com.blockstream.green.auth_key_lightning" // for lightning certs
        case AuthKeyPrivate = "com.blockstream.green.auth_key_private" // for biometric private key
        case AuthKeyLightning = "com.blockstream.green.auth_key_credentials" // for lightning credentials
        case AuthKeyWoCredentials = "com.blockstream.green.auth_key_wo_credentials" // for wathonly credentials
        case AuthKeyWoBioCredentials = "com.blockstream.green.auth_key_wo_bio_credentials" // for wathonly credentials with bio auth
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
            NSLog(error?.localizedDescription ?? "")
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
            let err = SecCopyErrorMessageString(status, nil)
            logger.error("AUTH error \(status, privacy: .public): \(String(describing: err), privacy: .public)")
        }
        return status
    }

    fileprivate static func describeSecurityError(_ error: CFError) -> String {
        let err = CFErrorCopyDescription(error)
        let errorString = String(describing: err!)
        logger.error("AUTH error: \(errorString, privacy: .public)")
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

    static func removeAuthKeyBiometricPrivateKey(network: String) throws {
        let label = "AuthKeyBiometricPrivateKey\(network)"
        UserDefaults.standard.removeObject(forKey: label)
        if removeAuth(method: .AuthKeyPrivate, for: label) == false {
            throw AuthError.SecurityError("Bio key not found")
        }
    }
    static func setAuthKeyBiometricPrivateKey(network: String, value: String) throws {
        let label = "AuthKeyBiometricPrivateKey\(network)"
        try set(method: .AuthKeyPrivate, data: [label: value], forNetwork: label)
    }

    static func getAuthKeyBiometricPrivateKey(network: String) throws -> String {
        let label = "AuthKeyBiometricPrivateKey\(network)"
        let res = try? get_(method: .AuthKeyPrivate, forNetwork: label)
        if let value = res?[label] as? String {
            return value
        }
        // migration from legacy local userdefaults
        if let privateKey = UserDefaults.standard.string(forKey: "AuthKeyBiometricPrivateKey\(network)") {
            // overwrite value on UserDefault with appgroup
            do {
                try setAuthKeyBiometricPrivateKey(network: network, value: privateKey)
                UserDefaults.standard.removeObject(forKey: "AuthKeyBiometricPrivateKey\(network)")
                logger.info("Migration BiometricPrivateKey successfull")
            } catch {
                logger.error("Migration BiometricPrivateKey failed: \(error.description(), privacy: .public)")
            }
            return privateKey
        }
        throw AuthError.SecurityError("Bio key not found")
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
        try setAuthKeyBiometricPrivateKey(network: network, value: privateKeyLabel)
    }

    fileprivate static func getPrivateKey(forNetwork: String) throws -> SecKey {
        guard let privateKeyLabel = try? getAuthKeyBiometricPrivateKey(network: forNetwork) else {
            throw AuthError.ServiceNotAvailable("Operation failed: Key not found.")
        }
        let context = LAContext()
        context.localizedReason = "Unlock Green"
        let q: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: ECCKeyType,
            kSecAttrKeySizeInBits: ECCKeySizeInBits,
            kSecAttrLabel: privateKeyLabel,
            kSecReturnRef: true,
            kSecUseAuthenticationContext: context]
        var privateKey: CFTypeRef?
        let status = callWrapper(fun: SecItemCopyMatching(q as CFDictionary, &privateKey))
        guard status == errSecSuccess else {
            throw AuthError.KeychainError("getPrivateKey", status)
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
            } else if CFErrorGetCode(cfError) == -8 {
                throw AuthError.LockedOut
            } else if CFErrorGetCode(cfError) == -1018 || CFErrorGetCode(cfError) == -3 {
                throw AuthError.DeniedByUser
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

    fileprivate static func queryForWrite(method: AuthType, forNetwork: String, version: Int) -> [CFString: Any] {
        var q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: method.rawValue,
            kSecAttrAccount: forNetwork]
        if version == 0 {
            q[kSecAttrAccessible] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        } else if version == 1 {
            q[kSecAttrAccessGroup] = Bundle.main.appGroup
            switch method {
            case .AuthKeyBiometric, .AuthKeyPrivate:
                q[kSecAttrAccessible] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            case .AuthKeyLightning, .AuthCertLightning:
                q[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            case .AuthKeyPIN, .AuthKeyWoCredentials:
                q[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
            case .AuthKeyWoBioCredentials:
                let access = SecAccessControlCreateWithFlags(
                    nil, // Use the default allocator.
                    kSecAttrAccessibleWhenUnlocked, // the item isn’t eligible for the iCloud keychain and won’t be included if the user restores a device backup to a new device.
                    .userPresence, // request biometric authentication, or to fall back on the device passcode, whenever the item is later read from the keychain.
                    nil) // Ignore any error.
                let context = LAContext()
                context.touchIDAuthenticationAllowableReuseDuration = 10
                q[kSecAttrAccessControl] = access
                q[kSecUseAuthenticationUI] = kSecUseAuthenticationUI
            }
        }
        return q
    }

    fileprivate static func queryForRead(method: AuthType, forNetwork: String, version: Int) -> [CFString: Any] {
        var q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: method.rawValue,
            kSecAttrAccount: forNetwork,
            kSecReturnData: kCFBooleanTrue ?? true]
        if version == 1 {
            q[kSecAttrAccessGroup] = Bundle.main.appGroup
            if method == .AuthKeyWoBioCredentials {
                let context = LAContext()
                context.localizedReason = "Access your mnemonic on the keychain"
                context.touchIDAuthenticationAllowableReuseDuration = 10
                q[kSecUseAuthenticationContext] = context
            }
        }
        return q
    }

    fileprivate static func queryForExist(method: AuthType, forNetwork: String, version: Int) -> [CFString: Any] {
        var q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: method.rawValue,
            kSecAttrAccount: forNetwork,
            kSecReturnData: kCFBooleanTrue ?? true]
        if version == 1 {
            q[kSecAttrAccessGroup] = Bundle.main.appGroup
            if method == .AuthKeyWoBioCredentials {
                let context = LAContext()
                context.interactionNotAllowed = true
                q[kSecUseAuthenticationContext] = context
            }
        }
        return q
    }

    fileprivate static func set(method: AuthType, data: [String: Any], forNetwork: String) throws {
        if [AuthType.AuthKeyBiometric, AuthType.AuthKeyWoBioCredentials].contains(method) && !supportsPasscodeAuthentication() {
            throw AuthError.PasscodeNotSet
        }
        guard let data = try? JSONSerialization.data(withJSONObject: data) else {
            throw AuthError.ServiceNotAvailable("Operation failed: Invalid json on serialization.")
        }
        let q = queryForWrite(method: method, forNetwork: forNetwork, version: 1)
        let qAdd = q.merging([kSecValueData: data]) { (current, _) in current }
        var status = callWrapper(fun: SecItemAdd(qAdd as CFDictionary, nil))
        if status == errSecDuplicateItem {
            status = callWrapper(fun: SecItemDelete(q as CFDictionary))
            status = callWrapper(fun: SecItemAdd(qAdd as CFDictionary, nil))
        }
        if status != errSecSuccess {
            throw AuthError.KeychainError("set", status)
        }
    }

    fileprivate static func get_(method: AuthType, forNetwork: String, version: Int = 1) throws -> [String: Any] {
        let q = queryForRead(method: method, forNetwork: forNetwork, version: version)
        var result: CFTypeRef?
        let status = callWrapper(fun: SecItemCopyMatching(q as CFDictionary, &result))
        guard status == errSecSuccess, result != nil, let resultData = result as? Data else {
            throw AuthError.KeychainError("get", status)
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
            if [AuthType.AuthKeyBiometric, AuthType.AuthKeyPIN, AuthType.AuthKeyPrivate].contains(method) {
                data = try get_(method: method, forNetwork: forNetwork, version: 0)
            }
        }
        if data.isEmpty {
            throw AuthError.ServiceNotAvailable("Authentication method not found")
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

    fileprivate static func exist_(method: AuthType, forNetwork: String, version: Int = 1) throws {
        let q = queryForExist(method: method, forNetwork: forNetwork, version: version)
        var result: CFTypeRef?
        let status = callWrapper(fun: SecItemCopyMatching(q as CFDictionary, &result))
        if status != errSecSuccess && status != errSecInteractionNotAllowed {
            throw AuthError.KeychainError("exist", status)
        }
    }

    public static func findAuth(method: AuthType, forNetwork: String) -> Bool {
        do {
            try exist_(method: method, forNetwork: forNetwork)
            return true
        } catch {
            do {
                try exist_(method: method, forNetwork: forNetwork, version: 0)
                return true
            } catch {
                return false
            }
        }
    }

    public static func removePrivateKey(forNetwork: String) {
        if let privateKeyLabel = try? getAuthKeyBiometricPrivateKey(network: forNetwork) {
            let q: [CFString: Any] = [kSecClass: kSecClassKey,
                                      kSecAttrKeyType: ECCKeyType,
                                      kSecAttrKeySizeInBits: ECCKeySizeInBits,
                                      kSecAttrLabel: privateKeyLabel,
                                      kSecReturnRef: true]
            let status = callWrapper(fun: SecItemDelete(q as CFDictionary))
        }
        try? removeAuthKeyBiometricPrivateKey(network: forNetwork)
    }

    public static func removeAuth(method: AuthType, for label: String) -> Bool {
        let q0 = queryForWrite(method: method, forNetwork: label, version: 0)
        _ = callWrapper(fun: SecItemDelete(q0 as CFDictionary)) == errSecSuccess
        let q1 = queryForWrite(method: method, forNetwork: label, version: 1)
        return callWrapper(fun: SecItemDelete(q1 as CFDictionary)) == errSecSuccess
    }

    private static func setAuth<T: Codable>(method: AuthType, data: T, for label: String) throws {
        if let data = data.toDict() {
            try set(method: method, data: data, forNetwork: label)
            return
        }
        throw AuthError.SecurityError("Invalid auth")
    }

    private static func getAuth<T: Codable>(method: AuthType, for label: String) throws -> T {
        let data = try get(method: method, toDecrypt: method == .AuthKeyBiometric, forNetwork: label)
        if let res = T.from(data) as? T {
            return res
        }
        throw AuthError.SecurityError("Invalid auth")
    }

    // Set methods
    public static func setPinData(method: AuthType, pinData: PinData, extraData: String?, for label: String) throws {
        guard [AuthType.AuthKeyPIN, AuthType.AuthKeyBiometric].contains(method) else {
            throw AuthError.SecurityError("Invalid method")
        }
        var pinData = pinData
        if method == .AuthKeyBiometric {
            if (try? getAuthKeyBiometricPrivateKey(network: label)) == nil {
                try AuthenticationTypeHandler.generateBiometricPrivateKey(network: label)
            }
            let encrypted = try encrypt(plaintext: extraData ?? "", forNetwork: label)
            pinData.encryptedBiometric = encrypted
        }
        try AuthenticationTypeHandler.setAuth(method: method, data: pinData, for: label)
    }

    public static func setCredentials(method: AuthType, credentials: Credentials, for label: String) throws {
        guard [AuthType.AuthKeyLightning, AuthType.AuthKeyWoCredentials, AuthType.AuthKeyWoBioCredentials].contains(method) else {
            throw AuthError.SecurityError("Invalid method")
        }
        try AuthenticationTypeHandler.setAuth(method: method, data: credentials, for: label)
    }
    public static func setCertLightning(credentials: AppGreenlightCredentials, for label: String) throws {
        try setAuth(method: .AuthCertLightning, data: credentials, for: label)
    }

    // Get methods
    public static func getPinData(method: AuthType, for label: String) throws -> PinData {
        guard [AuthType.AuthKeyPIN, AuthType.AuthKeyBiometric].contains(method) else {
            throw AuthError.SecurityError("Invalid method")
        }
        return try getAuth(method: method, for: label)
    }
    public static func getCredentials(method: AuthType, for label: String) throws -> Credentials {
        guard [AuthType.AuthKeyLightning, AuthType.AuthKeyWoCredentials, AuthType.AuthKeyWoBioCredentials].contains(method) else {
            throw AuthError.SecurityError("Invalid method")
        }
        return try getAuth(method: method, for: label)
    }
    public static func getCertLightning(for label: String) throws -> AppGreenlightCredentials {
        try getAuth(method: AuthType.AuthCertLightning, for: label)
    }
}
