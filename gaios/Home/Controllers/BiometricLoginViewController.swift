import Foundation
import LocalAuthentication
import UIKit
import core
import gdk
import greenaddress

class BiometricLoginViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var biometricButton: UIButton!
    @IBOutlet weak var pinButton: UIButton!

    var viewModel: LoginViewModel!
    private var account: Account { viewModel.account }

    override func viewDidLoad() {
        super.viewDidLoad()
        setStyle()
        setContent()
        setNavigation()
        AnalyticsManager.shared.recordView(.login, sgmt: AnalyticsManager.shared.sessSgmt(account))
    }

    func setNavigation() {
        navigationItem.title = ""
        navigationItem.setHidesBackButton(false, animated: false)
    }

    func setContent() {
        titleLabel.text = account.name.localized
        subtitleLabel.text = "Try Face ID again or enter your PIN to unlock your wallet.".localized
        let attrTitle = NSAttributedString(string: "Type PIN".localized, attributes: [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.thick.rawValue, NSAttributedString.Key.foregroundColor: UIColor.gAccent()])
        pinButton.setAttributedTitle(attrTitle, for: .normal)
        pinButton.isHidden = !account.hasManualPin
        biometricButton.setTitle("", for: .normal)
        switch AuthenticationTypeHandler.biometryType {
        case .faceID:
            biometricButton.setImage(UIImage(systemName: "faceid"), for: .normal)
        case .touchID:
            biometricButton.setImage(UIImage(systemName: "touchid"), for: .normal)
        default:
            biometricButton.setImage(UIImage(), for: .normal)
        }
    }

    func setStyle() {
        view.backgroundColor = UIColor.gBlackBg()
        pinButton.setStyle(.inline)
        titleLabel.setStyle(.title)
        subtitleLabel.setStyle(.txtCard)
        biometricButton.backgroundColor = UIColor.gAccent()
        biometricButton.cornerRadius = biometricButton.frame.size.width / 2
    }

    @IBAction func biometricButtonTap(_ sender: Any) {
        autologin()
    }

    @IBAction func pinButtonTap(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let vcLogin = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController
        if let vcLogin = vcLogin {
            vcLogin.viewModel = viewModel
            vcLogin.viewModel.autologin = false
            navigationController?.pushViewController(vcLogin, animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if viewModel.autologin {
            autologin()
        }
    }

    func autologin() {
        if AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: account.keychain) {
            Task { [weak self] in
                await self?.login(usingAuth: .AuthKeyBiometric)
            }
        } else if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoCredentials, forNetwork: account.keychain) {
            Task { [weak self] in
                await self?.login(usingAuth: .AuthKeyWoCredentials)
            }
        } else {
            if !AuthenticationTypeHandler.supportsPasscodeAuthentication() {
                showAlert(title: "id_error".localized, message: "id_set_up_a_passcode_for_your_ios".localized)
            }
        }
    }

    @MainActor
    fileprivate func login(usingAuth: AuthenticationTypeHandler.AuthType) async {
        AnalyticsManager.shared.loginWalletStart()
        self.startLoader(message: "id_logging_in".localized)
        let account = viewModel.account
        let task = Task.detached { [weak self] in
            switch usingAuth {
            case .AuthKeyWoCredentials:
                let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoCredentials, for: account.keychain)
                _ = try await self?.viewModel.loginWithCredentials(credentials: credentials)
            case .AuthKeyBiometric:
                try await self?.viewModel.loginWithPin(usingAuth: .AuthKeyBiometric, withPIN: nil, bip39passphrase: nil)
            default:
                break
            }
        }
        switch await task.result {
        case .success:
            success()
        case .failure(let error):
            failure(error: error, enableFailingCounter: true)
        }
    }

    @MainActor
    func success() {
        self.startLoader(message: "id_loading_wallet".localized)
        AnalyticsManager.shared.loginWalletEnd(account: account, loginType: .biometrics)
        AnalyticsManager.shared.activeWalletStart()
        BackupHelper.shared.cleanDismissedCache(walletId: account.id)
        AccountNavigator.navLogged(accountId: account.id)
    }

    func failureAuthError(error: AuthenticationTypeHandler.AuthError) {
        switch error {
        case .DeniedByUser:
            presentAlertDialogFaceId()
        case .LockedOut:
            presentBioAuthError("Too many attempts. Retry later".localized)
        case .CanceledByUser:
            break
        case .KeychainError:
            presentBioAuthError(error.description(), enableReset: true)
        case .SecurityError(let desc):
            presentBioAuthError(desc)
        case .PasscodeNotSet:
            presentBioAuthError("Passcode not set".localized)
        case .NotSupported:
            presentBioAuthError("Auth not supported".localized)
        case .ServiceNotAvailable:
            presentBioAuthError("Service not available".localized)
        }
    }

    @MainActor
    func failure(error: Error, enableFailingCounter: Bool) {
        self.stopLoader()
        AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: error.description())
        if let error = error as? AuthenticationTypeHandler.AuthError {
            failureAuthError(error: error)
            return
        }
        switch error {
        case LoginError.connectionFailed:
            DropAlert().error(message: "id_connection_failed".localized)
            AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: "id_connection_failed")
        case LoginError.walletNotFound:
            let msg = "id_wallet_not_found"
            DropAlert().error(message: msg.localized)
            showError(msg: msg)
        case GaError.NotAuthorizedError(_):
            AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: "id_not_authorized")
        case TwoFactorCallError.failure(let msg):
            if msg.contains("id_connection_failed") {
                DropAlert().error(message: msg.localized)
            } else {
                DropAlert().error(message: msg.localized)
                showError(msg: msg)
            }
            AnalyticsManager.shared.failedWalletLogin(account: self.account, error: error, prettyError: msg)
        default:
            let msg = "id_login_failed"
            DropAlert().error(message: msg.localized)
            showError(msg: msg)
            AnalyticsManager.shared.failedWalletLogin(account: self.account, error: error, prettyError: msg)
        }
    }
    func showError(msg: String) {
        let alert = UIAlertController(title: "id_error".localized, message: msg.localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_contact_support".localized, style: .cancel) { _ in
            self.showReportError(msg: msg)
        })
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .destructive) { _ in })
        self.present(alert, animated: true, completion: nil)
    }

    func showReportError(msg: String) {
        let request = ZendeskErrorRequest(
            error: msg,
            network: viewModel.account.networkType,
            paymentHash: nil,
            screenName: "Login")
        presentContactUsViewController(request: request)
    }

    func presentBioAuthError(_ message: String, enableReset: Bool = false) {
        let alert = UIAlertController(title: "id_warning".localized, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .default) { _ in })
        if enableReset {
            alert.addAction(UIAlertAction(title: "id_reset".localized, style: .destructive) { _ in
                self.account.removeBioKeychainData()
            })
        }
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    func presentAlertDialogFaceId() {
        let msg = "Biometric access disabled. Enable it from iOS settings"
        let alert = UIAlertController(title: "id_warning".localized, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open Settings".localized, style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        })
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .destructive) { _ in })
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension BiometricLoginViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        if let presented = presented as? DrawerNetworkSelectionViewController {
            return DrawerPresentationController(presentedViewController: presented, presenting: presenting)
        }
        return ModalPresentationController(presentedViewController: presented, presenting: presenting)
    }
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if presented is DrawerNetworkSelectionViewController {
            return DrawerAnimator(isPresenting: true)
        } else {
            return ModalAnimator(isPresenting: true)
        }
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if dismissed is DrawerNetworkSelectionViewController {
            return DrawerAnimator(isPresenting: false)
        } else {
            return ModalAnimator(isPresenting: false)
        }
    }
}
