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
    @IBOutlet weak var walletLabel: UILabel!
    @IBOutlet weak var walletImageBox: UIView!
    @IBOutlet weak var walletImage: UIImageView!
    @IBOutlet weak var walletBox: UIView!

    var viewModel: LoginViewModel!
    private var account: Account { viewModel.account }

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        setNavigation()
        AnalyticsManager.shared.recordView(.login, sgmt: AnalyticsManager.shared.sessSgmt(account))
    }

    func setNavigation() {
        navigationItem.title = ""
        navigationItem.setHidesBackButton(false, animated: false)
    }

    func setContent() {
        titleLabel.text = "Hello".localized
        subtitleLabel.text = "Try Face ID again or enter your PIN to unlock your wallet.".localized
        pinButton.setTitle("Type PIN".localized, for: .normal)
        biometricButton.setTitle("", for: .normal)
        let walletTap = UITapGestureRecognizer(target: self, action: #selector(switchNetwork))
        walletBox.addGestureRecognizer(walletTap)
    }

    func setStyle() {
        view.backgroundColor = UIColor.gBlackBg()
        pinButton.setStyle(.outlined)
        titleLabel.setStyle(.title)
        subtitleLabel.setStyle(.subTitle)
        walletLabel.setStyle(.txtCard)
        walletImageBox.layer.cornerRadius = walletImageBox.frame.size.width / 2
        walletImageBox.backgroundColor = UIColor.gAccent()
        let iconName = account.networkType.testnet ? "ic_wallet_testnet" : "ic_wallet"
        walletImage.image = UIImage(named: iconName)?.maskWithColor(color: UIColor.gBlackBg())
        let attrText = NSAttributedString(string: account.name, attributes: [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.thick.rawValue, NSAttributedString.Key.foregroundColor: UIColor.gAccent()])
        walletLabel.attributedText = attrText
    }

    @objc func switchNetwork() {
        let storyboard = UIStoryboard(name: "DrawerNetworkSelection", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DrawerNetworkSelection") as? DrawerNetworkSelectionViewController {
            vc.transitioningDelegate = self
            vc.modalPresentationStyle = .custom
            vc.delegate = self
            present(vc, animated: true, completion: nil)
        }
    }

    @IBAction func biometricButtonTap(_ sender: Any) {
        autologin()
    }

    @IBAction func pinButtonTap(_ sender: Any) {
        let nv = UINavigationController()
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let vcLogin = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController
        if let vcLogin = vcLogin {
            nv.pushViewController(vcLogin, animated: false)
        }
        AccountNavigator.changeRoot(root: nv)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        autologin()
    }

    func autologin() {
        if account.hasBioPin {
            Task { [weak self] in
                await self?.login(usingAuth: .AuthKeyBiometric)
            }
        } else if account.hasBioCredentials {
            Task { [weak self] in
                await self?.login(usingAuth: .AuthKeyWoBioCredentials)
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
            if usingAuth == .AuthKeyWoBioCredentials {
                let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoBioCredentials, for: account.keychain)
                _ = try await self?.viewModel.loginWithCredentials(credentials: credentials)
            } else if usingAuth == .AuthKeyBiometric {
                try await self?.viewModel.loginWithPin(usingAuth: .AuthKeyBiometric, withPIN: nil, bip39passphrase: nil)
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
        AccountNavigator.goLogged(accountId: account.id)
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
            showReportError(account: account, wallet: nil, prettyError: msg, screenName: "Login")
        case GaError.NotAuthorizedError(_):
            AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: "id_not_authorized")
        case TwoFactorCallError.failure(let msg):
            if msg.contains("id_connection_failed") {
                DropAlert().error(message: msg.localized)
            } else {
                showReportError(account: account, wallet: nil, prettyError: msg, screenName: "Login")
                DropAlert().error(message: msg.localized)
            }
            AnalyticsManager.shared.failedWalletLogin(account: self.account, error: error, prettyError: msg)
        default:
            let msg = "id_login_failed"
            showReportError(account: account, wallet: nil, prettyError: msg, screenName: "Login")
            DropAlert().error(message: msg.localized)
            AnalyticsManager.shared.failedWalletLogin(account: self.account, error: error, prettyError: msg)
        }
    }

    func onBioAuthError(_ message: String) {
        let text = String(format: "id_syou_need_ton1_reset_greens".localized, message)
        let alert = UIAlertController(title: "id_warning".localized, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .default) { _ in })
        alert.addAction(UIAlertAction(title: "id_reset".localized, style: .destructive) { _ in
            self.account.removeBioKeychainData()
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
        if presented as? DrawerNetworkSelectionViewController != nil {
            return DrawerAnimator(isPresenting: true)
        } else {
            return ModalAnimator(isPresenting: true)
        }
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if dismissed as? DrawerNetworkSelectionViewController != nil {
            return DrawerAnimator(isPresenting: false)
        } else {
            return ModalAnimator(isPresenting: false)
        }
    }
}
extension BiometricLoginViewController: DrawerNetworkSelectionDelegate {

    // accounts drawer: add new waller
    func didSelectAddWallet() {
        AccountNavigator.goAddWallet(nv: navigationController)
    }

    // accounts drawer: select another account
    func didSelectAccount(account: Account) {
        // don't switch if same account selected
        if account.id == self.account.id {
            return
        } else if let wm = WalletsRepository.shared.get(for: account.id), wm.logged {
            AccountNavigator.goLogged(accountId: account.id)
        } else {
            AccountNavigator.goLogin(accountId: account.id)
        }
    }

    // accounts drawer: select app settings
    func didSelectSettings() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }

    func didSelectAbout() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAboutViewController") as? DialogAboutViewController {
                vc.modalPresentationStyle = .overFullScreen
                vc.delegate = self
                self.present(vc, animated: false, completion: nil)
            }
        })
    }
}
extension BiometricLoginViewController: DialogAboutViewControllerDelegate {
    func openContactUs() {
        let storyboard = UIStoryboard(name: "HelpCenter", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ContactUsViewController") as? ContactUsViewController {
            vc.request = ZendeskErrorRequest(shareLogs: true)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
