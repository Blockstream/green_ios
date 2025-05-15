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
            biometricButton.setImage(UIImage(named: "login_faceid"), for: .normal)
        case .touchID:
            biometricButton.setImage(UIImage(named: "login_touchid"), for: .normal)
        default:
            biometricButton.setImage(UIImage(), for: .normal)
        }
    }

    func setStyle() {
        view.backgroundColor = UIColor.gBlackBg()
        pinButton.setStyle(.inline)
        titleLabel.setStyle(.title)
        subtitleLabel.setStyle(.txtCard)
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
        } else if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoBioCredentials, forNetwork: account.keychain) {
            Task { [weak self] in
                await self?.login(usingAuth: .AuthKeyWoBioCredentials)
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
            case .AuthKeyWoBioCredentials:
                let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoBioCredentials, for: account.keychain)
                _ = try await self?.viewModel.loginWithCredentials(credentials: credentials)
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

    @MainActor
    func failure(error: Error, enableFailingCounter: Bool) {
        self.stopLoader()
        switch error {
        case AuthenticationTypeHandler.AuthError.CanceledByUser:
            AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: "id_action_cancel")
        case AuthenticationTypeHandler.AuthError.KeychainError:
            self.onBioAuthError(error.localizedDescription)
            AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: error.localizedDescription)
        case AuthenticationTypeHandler.AuthError.SecurityError(let desc):
            DropAlert().error(message: desc.localized)
            AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: desc)
        case LoginError.connectionFailed:
            DropAlert().error(message: "id_connection_failed".localized)
            AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: "id_connection_failed")
        case LoginError.walletNotFound:
            let msg = "id_wallet_not_found"
            DropAlert().error(message: msg.localized)
            showReportError(msg: msg)
        case GaError.NotAuthorizedError(_):
            AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: "id_not_authorized")
        case TwoFactorCallError.failure(let msg):
            if msg.contains("id_connection_failed") {
                DropAlert().error(message: msg.localized)
            } else {
                DropAlert().error(message: msg.localized)
                showReportError(msg: msg)
            }
            AnalyticsManager.shared.failedWalletLogin(account: self.account, error: error, prettyError: msg)
        default:
            let msg = "id_login_failed"
            DropAlert().error(message: msg.localized)
            showReportError(msg: msg)
            AnalyticsManager.shared.failedWalletLogin(account: self.account, error: error, prettyError: msg)
        }
    }
    func showReportError(msg: String) {
        let request = ZendeskErrorRequest(
            error: msg,
            network: viewModel.account.networkType,
            paymentHash: nil,
            screenName: "Login")
        presentContactUsViewController(request: request)
    }

    func onBioAuthError(_ message: String) {
        let text = String(format: "id_syou_need_ton1_reset_greens".localized, message)
        let alert = UIAlertController(title: "id_warning".localized, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .default) { _ in })
        alert.addAction(UIAlertAction(title: "id_reset".localized, style: .destructive) { _ in
            try? self.account.removeBioKeychainData()
        })
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
