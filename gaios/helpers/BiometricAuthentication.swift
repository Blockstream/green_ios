import LocalAuthentication

class BiometricAuthentication {
    let context = LAContext()

    func biometricType() -> LABiometryType? {
        if #available(iOS 11.3, *) {
            let _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            return context.biometryType
        }
        return nil
     }

    func canEvaluatePolicy() -> Bool {
        if #available(iOS 11.3, *) {
            return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        }
        return false
    }
}
