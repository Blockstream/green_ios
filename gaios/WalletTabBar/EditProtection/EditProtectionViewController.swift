import UIKit
import core

enum EditProtectionType {
    case pin
    case faceID
    case touchID
}
enum EditProtectionAction {
    case enable
    case disable
    case change
}
class EditProtectionViewController: UIViewController {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnNext: UIButton!

    var protectionType: EditProtectionType?
    var protectionAction: EditProtectionAction?

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
    }

    func setContent() {
        guard let protectionType = protectionType, let protectionAction = protectionAction else {
            navigationController?.popViewController(animated: true)
            return
        }
        switch protectionType {
        case .pin:
            icon.image = UIImage(named: "ic_edit_protection_pin")
            lblTitle.text = "PIN".localized
            lblHint.text = "Warning: If you forget your PIN and have not enabled biometrics or a recovery method, you will lose access to funds.".localized
            lblHint.isHidden = false
            switch protectionAction {
            case .enable:
                btnNext.setTitle("Enable".localized, for: .normal)
            case .disable:
                break
            case .change:
                btnNext.setTitle("Change PIN".localized, for: .normal)
            }
        case .faceID:
            icon.image = UIImage(systemName: "faceid")
            icon.tintColor = .white
            lblTitle.text = "FaceID".localized
            lblHint.isHidden = true
            switch protectionAction {
            case .enable:
                btnNext.setTitle("Enable".localized, for: .normal)
            case .disable:
                btnNext.setTitle("Disable".localized, for: .normal)
            case .change:
                break
            }
        case .touchID:
            icon.image = UIImage(systemName: "touchid")
            icon.tintColor = .white
            lblTitle.text = "Touch ID".localized
            lblHint.isHidden = true
            switch protectionAction {
            case .enable:
                btnNext.setTitle("Enable".localized, for: .normal)
            case .disable:
                btnNext.setTitle("Disable".localized, for: .normal)
            case .change:
                break
            }
        }
    }

    func setStyle() {
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txt)
        btnNext.setStyle(.primary)
    }

    @IBAction func btnNext(_ sender: Any) {
        guard let protectionType = protectionType,
              let protectionAction = protectionAction else {
            navigationController?.popViewController(animated: true)
            return
        }
        switch protectionType {
        case .pin:
            pushSetPinViewController()
        case .faceID, .touchID:
            Task { [weak self] in
                switch protectionAction {
                case .enable:
                    await self?.changeBiometricAuthentication(enable: true)
                case .disable:
                    await self?.changeBiometricAuthentication(enable: false)
                case .change:
                    break
                }
            }
        }
    }

    func changeBiometricAuthentication(enable: Bool) async {
        if !enable && !(WalletManager.current?.account.hasManualPin ?? false) {
            showAlert(
                title: (protectionType == .faceID ? "Face ID" : "Touch ID"),
                message: "Enable PIN before disabling " + (protectionType == .faceID ? "Face ID" : "Touch ID"))
            return
        }
        let task = Task.detached { [weak self] in
            if enable {
                try await self?.enableBiometricAuthentication()
            } else {
                await self?.disableBiometricAuthentication()
            }
        }
        switch await task.result {
        case .success:
            if enable {
                DropAlert().success(message: "id_biometric_login_is_enabled".localized)
            } else {
                DropAlert().success(message: "id_biometric_login_is_disabled".localized)
            }
            navigationController?.popViewController(animated: true)
        case .failure(let err):
            DropAlert().error(message: err.description().localized)
        }
    }

    func pushSetPinViewController() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SetPinViewController") as? SetPinViewController {
            vc.pinFlow = .settings
            vc.viewModel = OnboardViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func enableBiometricAuthentication() async throws {
        if let wm = WalletManager.current,
           let session = wm.prominentSession {
            let credentials = try await session.getCredentials(password: "")
            if let credentials = credentials {
                try await wm.account.addBiometrics(session: session, credentials: credentials)
                return
            }
        }
    }

    func disableBiometricAuthentication() async {
        guard let keychain = WalletManager.current?.account.keychain else { return }
        _ = AuthenticationTypeHandler.removeAuth(method: .AuthKeyBiometric, for: keychain)
        AuthenticationTypeHandler.removePrivateKey(forNetwork: keychain)
        UserDefaults.standard.set(nil, forKey: "AuthKeyBiometricPrivateKey\(keychain)")
    }
}
