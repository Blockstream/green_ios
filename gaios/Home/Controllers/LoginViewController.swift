import Foundation
import LocalAuthentication
import UIKit
import core
import gdk
import greenaddress

class LoginViewController: UIViewController {

    @IBOutlet weak var cardEnterPin: UIView!
    @IBOutlet weak var cardWalletLock: UIView!
    @IBOutlet weak var btnsStack: UIStackView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var attempts: UILabel!
    @IBOutlet weak var connectionSettingsButton: UIButton!
    @IBOutlet weak var emergencyButton: UIButton!
    @IBOutlet weak var attemptsView: UIView!
    @IBOutlet weak var attemptsBg: UIView!

    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet var keyButton: [UIButton]?
    @IBOutlet var pinLabel: [UILabel]?
    let menuButton = UIButton(type: .system)

    @IBOutlet weak var lblWalletLockHint1: UILabel!
    @IBOutlet weak var lblWalletLockHint2: UILabel!
    @IBOutlet weak var btnWalletLock: UIButton!

    @IBOutlet weak var alertCard: UIView!
    @IBOutlet weak var alertTitle: UILabel!
    @IBOutlet weak var alertHint: UILabel!
    @IBOutlet weak var alertIconWarn: UIImageView!
    @IBOutlet weak var alertBtnDismiss: UIButton!
    @IBOutlet weak var alertBtnRight: UIButton!
    @IBOutlet weak var alertBtnsContainer: UIView!

    var viewModel: LoginViewModel!

    private var account: Account { viewModel.account }
    private var remoteAlert: RemoteAlert?
    private var pinCode = ""
    private let MAXATTEMPTS = 3
    private var emergencyRestore = false {
        didSet {
            emergencyButton.isHidden = !emergencyRestore
        }
    }

    @IBOutlet weak var passphraseView: UIStackView!
    @IBOutlet weak var lblPassphrase: UILabel!

    var bip39passphare: String? {
        didSet {
            passphraseView.isHidden = bip39passphare?.isEmpty ?? true
        }
    }

    private var showLockPage: Bool {
        !emergencyRestore &&
        (account.attempts >= self.MAXATTEMPTS  || account.hasPin == false)
    }

    @IBAction func tap1(_ sender: Any) {
        tapNumber("1")
    }
    @IBAction func tap2(_ sender: Any) {
        tapNumber("2")
    }
    @IBAction func tap3(_ sender: Any) {
        tapNumber("3")
    }
    @IBAction func tap4(_ sender: Any) {
        tapNumber("4")
    }
    @IBAction func tap5(_ sender: Any) {
        tapNumber("5")
    }
    @IBAction func tap6(_ sender: Any) {
        tapNumber("6")
    }
    @IBAction func tap7(_ sender: Any) {
        tapNumber("7")
    }
    @IBAction func tap8(_ sender: Any) {
        tapNumber("8")
    }
    @IBAction func tap9(_ sender: Any) {
        tapNumber("9")
    }
    @IBAction func tapDelete(_ sender: Any) {
        if pinCode.count > 0 {
            pinCode.removeLast()
            reloadPin()
        }
    }
    @IBAction func tap0(_ sender: Any) {
        tapNumber("0")
    }
    @IBAction func tapCancel(_ sender: Any) {
        pinCode = ""
        reloadPin()
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        setNavigation()
        setRemoteAlert()

        view.accessibilityIdentifier = AccessibilityIdentifiers.LoginScreen.view
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = AccessibilityIdentifiers.LoginScreen.backBtn
        menuButton.accessibilityIdentifier = AccessibilityIdentifiers.LoginScreen.menuBtn
        keyButton![0].accessibilityIdentifier = AccessibilityIdentifiers.LoginScreen.btn1
        keyButton![1].accessibilityIdentifier = AccessibilityIdentifiers.LoginScreen.btn2
        keyButton![2].accessibilityIdentifier = AccessibilityIdentifiers.LoginScreen.btn3
        attempts.accessibilityIdentifier = AccessibilityIdentifiers.LoginScreen.attemptsLbl
        connectionSettingsButton.accessibilityIdentifier = AccessibilityIdentifiers.LoginScreen.settingsBtn

        AnalyticsManager.shared.recordView(.login, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))
    }

    func setNavigation() {
        navigationItem.title = account.name
        navigationItem.setHidesBackButton(true, animated: false)
        let ntwBtn = UIButton(type: .system)
        ntwBtn.setTitle("id_wallets".localized, for: .normal)
        ntwBtn.addTarget(self, action: #selector(LoginViewController.back), for: .touchUpInside)
        ntwBtn.contentEdgeInsets = UIEdgeInsets(top: 9, left: -10, bottom: 9, right: 0)
        navigationItem.leftBarButtonItems =
        [UIBarButtonItem(image: UIImage.init(named: "backarrow2"), style: UIBarButtonItem.Style.plain, target: self, action: #selector(LoginViewController.back)),
         UIBarButtonItem(customView: ntwBtn)
        ]
        menuButton.setImage(UIImage(named: "ellipses"), for: .normal)
        menuButton.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        menuButton.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: menuButton)
    }

    func setRemoteAlert() {
        alertCard.isHidden = true
        self.remoteAlert = RemoteAlertManager.shared.alerts(screen: .login, networks: [account.networkType]).first
        if remoteAlert != nil {
            alertCard.isHidden = false
            alertTitle.text = remoteAlert?.title?.htmlDecoded
            alertHint.text = remoteAlert?.message?.htmlDecoded
            alertTitle.isHidden = remoteAlert?.title?.isEmpty ?? true
            alertHint.isHidden = remoteAlert?.message?.isEmpty ?? true
            alertIconWarn.isHidden = !(remoteAlert?.isWarning ?? false)
            alertBtnRight.setTitle("id_learn_more".localized, for: .normal)
            alertBtnDismiss.isHidden = !(remoteAlert?.dismissable ?? false)
            alertBtnsContainer.isHidden = true
            if remoteAlert?.link != nil {
                if URL(string: remoteAlert?.link ?? "") != nil {
                    alertBtnsContainer.isHidden = false
                }
            }
        }
    }

    func setContent() {
        lblTitle.text = "id_enter_pin".localized
        lblWalletLockHint1.text = "\("id_youve_entered_an_invalid_pin".localized)\n\("id_youll_need_your_recovery_phrase".localized)"
        lblWalletLockHint2.isHidden = true
        btnWalletLock.setTitle("id_restore_with_recovery_phrase".localized, for: .normal)
        connectionSettingsButton.setTitle("id_app_settings".localized, for: .normal)
        cancelButton.setTitle("id_cancel".localized, for: .normal)
        lblPassphrase.text = "id_bip39_passphrase_login".localized
        emergencyButton.setTitle("id_emergency_recovery_phrase".localized, for: .normal)
        passphraseView.isHidden = true
    }

    func setStyle() {
        view.backgroundColor = UIColor.gBlackBg()
        btnWalletLock.setStyle(.primary)
        alertCard.layer.cornerRadius = 6.0
        attemptsBg.layer.cornerRadius = 5.0
        attemptsBg.backgroundColor = UIColor.gRedWarn()
        emergencyButton.setTitleColor(.white, for: .normal)
        emergencyButton.borderWidth = 1.0
        emergencyButton.borderColor = .white.withAlphaComponent(0.5)
        emergencyButton.setImage(UIImage(named: "ic_x_circle")!.maskWithColor(color: .white), for: .normal)
        emergencyButton.cornerRadius = 5.0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(progressTor), name: NSNotification.Name(rawValue: EventType.Tor.rawValue), object: nil)
        updateAttemptsLabel()
        reloadPin()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if account.askEphemeral ?? false {
            loginWithPassphrase(isAlwaysAsk: account.askEphemeral ?? false)
        } else if account.hasBioPin {
            loginWithPin(usingAuth: .AuthKeyBiometric, withPIN: nil, bip39passphrase: nil)
        } else {
            if !AuthenticationTypeHandler.supportsPasscodeAuthentication() {
                showAlert(title: "id_error".localized, message: "id_set_up_a_passcode_for_your_ios".localized)
            }
        }
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Tor.rawValue), object: nil)
    }

    @objc func menuButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {

            vc.viewModel = DialogListViewModel(title: "More Options", type: .loginPrefs, items: LoginPrefs.getItems(isWatchOnly: false))
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @objc func progressTor(_ notification: NSNotification) {
        if let json = try? JSONSerialization.data(withJSONObject: notification.userInfo!, options: []),
           let tor = try? JSONDecoder().decode(TorNotification.self, from: json) {
            var text = "id_tor_status".localized + " \(tor.progress)%"
            if tor.progress == 100 {
                text = "id_logging_in".localized
            }
            DispatchQueue.main.async {
                self.updateLoader(message: text)
            }
        }
    }

    @objc func updateNetwork(_ notification: NSNotification) {
        if let dict = notification.userInfo as? [String: Any],
           let connection = Connection.from(dict) as? Connection,
           let error = connection.error {
            DispatchQueue.main.async {
                DropAlert().warning(message: error)
            }
        }
    }

    fileprivate func decryptMnemonic(usingAuth: AuthenticationTypeHandler.AuthType, withPIN: String?, bip39passphrase: String?) {
        self.startLoader(message: "id_logging_in".localized)
        Task.detached() { [weak self] in
            do {
                let credentials = try await self?.viewModel.decryptCredentials(usingAuth: usingAuth, withPIN: withPIN)
                if var credentials = credentials {
                    credentials.bip39Passphrase = bip39passphrase
                    await self?.successDecrypt(credentials)
                }
            } catch {
                await self?.failure(error: error, enableFailingCounter: false)
            }
        }
    }

    @MainActor
    fileprivate func successDecrypt(_ credentials: Credentials) {
        self.stopLoader()
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ShowMnemonicsViewController") as? ShowMnemonicsViewController {
            vc.credentials = credentials
            self.navigationController?.pushViewController(vc, animated: true)
        }
        self.pinCode = ""
        self.reloadPin()
    }

    fileprivate func loginWithPin(usingAuth: AuthenticationTypeHandler.AuthType, withPIN: String?, bip39passphrase: String?) {
        AnalyticsManager.shared.loginWalletStart()
        self.startLoader(message: "id_logging_in".localized)
        Task.detached() { [weak self] in
            do {
                try await self?.viewModel.loginWithPin(usingAuth: usingAuth, withPIN: withPIN, bip39passphrase: bip39passphrase)
                await self?.success(withPIN: withPIN != nil)
            } catch {
                await self?.failure(error: error, enableFailingCounter: true)
            }
        }
    }

    @MainActor
    func success(withPIN: Bool) {
        self.startLoader(message: "id_loading_wallet".localized)
        AnalyticsManager.shared.loginWalletEnd(account: account,
                                               loginType: withPIN ? .pin : .biometrics)
        AnalyticsManager.shared.activeWalletStart()
        _ = AccountNavigator.goLogged(account: account)
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
            self.wrongPin()
            AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: "id_not_authorized")
        case TwoFactorCallError.failure(let msg):
            if msg.contains("id_connection_failed") {
                DropAlert().error(message: msg.localized)
            } else if msg.contains("login failed") || msg.contains("id_invalid_pin") {
                if enableFailingCounter {
                    wrongPin()
                }
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
        self.pinCode = ""
        self.reloadPin()
    }

    @IBAction func emergencyClick(_ sender: Any) {
        emergencyRestore = false
    }

    func wrongPin() {
        viewModel.updateAccountAttempts(account.attempts + 1)
        if account.attempts == self.MAXATTEMPTS {
            WalletsRepository.shared.delete(for: account)
            self.reload()
        } else {
            self.pinCode = ""
            self.updateAttemptsLabel()
            self.reloadPin()
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

    func reload() {
        let showLockPage = !emergencyRestore && (account.attempts >= self.MAXATTEMPTS  || account.hasPin == false)
        cardEnterPin.isHidden = showLockPage
        lblTitle.isHidden = showLockPage
        cardWalletLock.isHidden = !showLockPage
        attempts.isHidden = emergencyRestore || account.attempts == 0
        attemptsView.isHidden = emergencyRestore || account.attempts == 0
    }

    func updateAttemptsLabel() {
        let pinattempts = account.attempts
        if pinattempts == MAXATTEMPTS {
            reload()
        } else if MAXATTEMPTS - pinattempts == 1 {
            attempts.text = "id_last_attempt_if_failed_you_will".localized
        } else {
            attempts.text = String(format: "id_attempts_remaining_d".localized, MAXATTEMPTS - pinattempts)
        }
        attempts.isHidden = emergencyRestore || pinattempts == 0
        attemptsView.isHidden = emergencyRestore || pinattempts == 0
    }

    func tapNumber(_ number: String) {
        pinCode += number
        reloadPin()
        guard pinCode.count == 6 else {
            return
        }
        if emergencyRestore {
            decryptMnemonic(usingAuth: .AuthKeyPIN,
                            withPIN: pinCode,
                            bip39passphrase: bip39passphare)
            return
        }
        loginWithPin(usingAuth: .AuthKeyPIN,
                     withPIN: pinCode,
                     bip39passphrase: bip39passphare)
    }

    func reloadPin() {
        pinLabel?.enumerated().forEach {(index, label) in
            if index < pinCode.count {
                label.textColor = UIColor.customMatrixGreen()
            } else {
                label.textColor = UIColor.black
            }
        }
    }

    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    func walletDelete() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogDeleteViewController") as? DialogDeleteViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    func walletRename() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogRenameViewController") as? DialogRenameViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.index = nil
            vc.prefill = account.name
            present(vc, animated: false, completion: nil)
        }
    }

    func showEmergencyDialog() {
        let alert = UIAlertController(title: "Emergency Recovery Phrase Restore".localized,
                                      message: "If for any reason you can't login into your wallet, you can recover your recovery phrase using your PIN/Biometrics.".localized,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { (_: UIAlertAction) in })
        alert.addAction(UIAlertAction(title: "id_ok".localized, style: .default) { (_: UIAlertAction) in
            self.emergencyRestore = true
            self.reload()
            if self.account.hasBioPin {
                self.decryptMnemonic(usingAuth: .AuthKeyBiometric, withPIN: nil, bip39passphrase: nil)
            }
        })
        self.present(alert, animated: true, completion: nil)
    }

    func loginWithPassphrase(isAlwaysAsk: Bool) {

        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogPassphraseViewController") as? DialogPassphraseViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.isAlwaysAsk = isAlwaysAsk
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnFaceID(_ sender: Any) {
    }

    @IBAction func btnSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnWalletLock(_ sender: Any) {
        OnBoardManager.shared.flowType = .restore
        OnBoardParams.shared = OnBoardParams(testnet: account.gdkNetwork.mainnet,
                                             walletName: account.name,
                                             accountId: account.id,
                                             xpubHashId: account.xpubHashId)
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "MnemonicViewController") as? MnemonicViewController {
            vc.restoredAccount = account
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func alertDismiss(_ sender: Any) {
        alertCard.isHidden = true
    }

    @IBAction func alertLink(_ sender: Any) {
        SafeNavigationManager.shared.navigate(remoteAlert?.link)
    }
}

extension LoginViewController: DialogRenameViewControllerDelegate, DialogDeleteViewControllerDelegate {
    func didRename(name: String, index: String?) {
        viewModel.updateAccountName(name)
        navigationItem.title = account.name
    }
    func didDelete(_ index: String?) {
        Task {
            self.startLoader(message: "Removing wallet…".localized)
            await AccountsRepository.shared.remove(account)
            await MainActor.run {
                self.stopLoader()
                navigationController?.popViewController(animated: true)
                AnalyticsManager.shared.deleteWallet()
            }
        }
    }
    func didCancel() {
    }
}

extension LoginViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }
}

extension LoginViewController: DialogPassphraseViewControllerDelegate {
    func didConfirm(passphrase: String, alwaysAsk: Bool) {
        bip39passphare = passphrase
        viewModel.updateAccountAskEphemeral(alwaysAsk)
        if account.hasBioPin {
            loginWithPin(usingAuth: .AuthKeyBiometric, withPIN: nil, bip39passphrase: passphrase)
        }
    }
}

extension LoginViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .loginPrefs:
            switch LoginPrefs(rawValue: index) {
            case .emergency:
                showEmergencyDialog()
            case .passphrase:
                loginWithPassphrase(isAlwaysAsk: false)
            case .edit:
                walletRename()
            case .delete:
                walletDelete()
            case .none:
                break
            }
        default:
            break
        }
    }
}
