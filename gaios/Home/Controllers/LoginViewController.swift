import Foundation
import LocalAuthentication
import UIKit

import gdk
import greenaddress

class LoginViewController: UIViewController {

    @IBOutlet weak var cardEnterPin: UIView!
    @IBOutlet weak var cardWalletLock: UIView!
    @IBOutlet weak var cardLoginShortcut: UIView!
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
    @IBOutlet weak var btnLoginShortcut: UIButton!
    
    @IBOutlet weak var alertCard: UIView!
    @IBOutlet weak var alertTitle: UILabel!
    @IBOutlet weak var alertHint: UILabel!
    @IBOutlet weak var alertIconWarn: UIImageView!
    @IBOutlet weak var alertBtnDismiss: UIButton!
    @IBOutlet weak var alertBtnRight: UIButton!
    @IBOutlet weak var alertBtnsContainer: UIView!

    var account: Account!

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
        !account.isDerivedLightning &&
        (account?.attempts ?? 0 >= self.MAXATTEMPTS  || account?.hasPin == false)
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
        let img = UIImage(named: account.gdkNetwork.mainnet == true ? "ic_wallet" : "ic_wallet_testnet")!.maskWithColor(color: .white)
        ntwBtn.setImage(img, for: .normal)
        ntwBtn.imageView?.contentMode = .scaleAspectFit
        ntwBtn.addTarget(self, action: #selector(LoginViewController.back), for: .touchUpInside)
        ntwBtn.contentEdgeInsets = UIEdgeInsets(top: 9, left: -10, bottom: 9, right: 0)
        navigationItem.leftBarButtonItems =
            [UIBarButtonItem(image: UIImage.init(named: "backarrow2"), style: UIBarButtonItem.Style.plain, target: self, action: #selector(LoginViewController.back)),
             UIBarButtonItem(customView: ntwBtn)
            ]
        menuButton.setImage(UIImage(named: "ellipses"), for: .normal)
        menuButton.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        menuButton.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        menuButton.isHidden = account.isDerivedLightning
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: menuButton)
    }

    func setRemoteAlert() {
        alertCard.isHidden = true
        self.remoteAlert = RemoteAlertManager.shared.alerts(screen: .login, networks: [account.networkType]).first
        if remoteAlert != nil {
            alertCard.isHidden = false
            alertTitle.text = remoteAlert?.title
            alertHint.text = remoteAlert?.message
            alertTitle.isHidden = remoteAlert?.title?.isEmpty ?? true
            alertHint.isHidden = remoteAlert?.message?.isEmpty ?? true
            alertIconWarn.isHidden = !(remoteAlert?.isWarning ?? false)
            alertBtnRight.setTitle(NSLocalizedString("id_learn_more", comment: ""), for: .normal)
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
        lblTitle.text = account.isDerivedLightning ? "Lightning Shortcut".localized : "id_enter_pin".localized
        lblWalletLockHint1.text = "\("id_youve_entered_an_invalid_pin".localized)\n\("id_youll_need_your_recovery_phrase".localized)"
        lblWalletLockHint2.isHidden = true
        btnWalletLock.setTitle("id_restore_with_recovery_phrase".localized, for: .normal)
        connectionSettingsButton.setTitle("id_app_settings".localized, for: .normal)
        cancelButton.setTitle("id_cancel".localized, for: .normal)
        lblPassphrase.text = "id_bip39_passphrase_login".localized
        emergencyButton.setTitle("id_emergency_recovery_phrase".localized, for: .normal)
        btnLoginShortcut.setTitle("id_login_with_biometrics".localized, for: .normal)
        passphraseView.isHidden = true
    }

    func setStyle() {
        btnWalletLock.setStyle(.primary)
        btnLoginShortcut.setStyle(.primary)
        alertCard.layer.cornerRadius = 6.0
        attemptsBg.layer.cornerRadius = 5.0
        emergencyButton.setTitleColor(.white, for: .normal)
        emergencyButton.borderWidth = 1.0
        emergencyButton.borderColor = .white.withAlphaComponent(0.5)
        emergencyButton.setImage(UIImage(named: "ic_x_circle")!.maskWithColor(color: .white), for: .normal)
        emergencyButton.cornerRadius = 5.0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ScreenLocker.shared.stopObserving()
        NotificationCenter.default.addObserver(self, selector: #selector(progressTor), name: NSNotification.Name(rawValue: EventType.Tor.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateNetwork), name: NSNotification.Name(rawValue: EventType.Network.rawValue), object: nil)

        cancelButton.addTarget(self, action: #selector(click(sender:)), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(click(sender:)), for: .touchUpInside)
        for button in keyButton!.enumerated() {
            button.element.addTarget(self, action: #selector(keyClick(sender:)), for: .touchUpInside)
        }
        updateAttemptsLabel()
        reloadPin()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if account.askEphemeral ?? false {
            loginWithPassphrase(isAlwaysAsk: account.askEphemeral ?? false)
        } else if account.isDerivedLightning {
            loginWithLightningShortcut()
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
        ScreenLocker.shared.startObserving()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Tor.rawValue), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Network.rawValue), object: nil)

        cancelButton.removeTarget(self, action: #selector(click(sender:)), for: .touchUpInside)
        deleteButton.removeTarget(self, action: #selector(click(sender:)), for: .touchUpInside)
        for button in keyButton!.enumerated() {
            button.element.removeTarget(self, action: #selector(keyClick(sender:)), for: .touchUpInside)
        }
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
            var text = NSLocalizedString("id_tor_status", comment: "") + " \(tor.progress)%"
            if tor.progress == 100 {
                text = NSLocalizedString("id_logging_in", comment: "")
            }
            DispatchQueue.main.async {
                self.startLoader(message: text)
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
        self.startLoader(message: NSLocalizedString("id_logging_in", comment: ""))
        Task(priority: .background) {
            do {
                let session = SessionManager(account.gdkNetwork)
                try await session.connect()
                let pinData = try self.account.auth(usingAuth)
                let decrypt = DecryptWithPinParams(pin: withPIN ?? "", pinData: pinData)
                let credentials = try await session.decryptWithPin(decrypt)
                successDecrypt(credentials)
            } catch {
                failure(error: error, enableFailingCounter: false)
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
    
    func auth() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let context = LAContext()
            var error : NSError?
            context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
            if let error = error {
                continuation.resume(throwing: AuthenticationTypeHandler.AuthError.CanceledByUser)
            }
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authentication" ) { success, error in
                if let error = error {
                    continuation.resume(throwing: AuthenticationTypeHandler.AuthError.CanceledByUser)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    fileprivate func loginWithLightningShortcut() {
        AnalyticsManager.shared.loginWalletStart()
        self.startLoader(message: NSLocalizedString("id_logging_in", comment: ""))
        Task(priority: .background) {
            do {
                let wm = WalletsRepository.shared.getOrAdd(for: account)
                try await auth()
                let credentials = try AuthenticationTypeHandler.getAuthKeyCredentials(forNetwork: account.keychain)
                _ = try await wm.login(credentials: credentials, lightningCredentials: credentials)
                AccountsRepository.shared.current = account
                success(withPIN: false, account: account)
            } catch {
                failure(error: error, enableFailingCounter: true)
            }
        }
    }

    fileprivate func loginWithPin(usingAuth: AuthenticationTypeHandler.AuthType, withPIN: String?, bip39passphrase: String?) {
        var currentAccount = account!
        if !account.isEphemeral && !bip39passphrase.isNilOrEmpty {
            currentAccount = Account(name: account.name, network: account.networkType, keychain: account.keychain)
            currentAccount.isEphemeral = true
            currentAccount.attempts = account.attempts
            currentAccount.xpubHashId = account.xpubHashId
        }
        AnalyticsManager.shared.loginWalletStart()
        self.startLoader(message: NSLocalizedString("id_logging_in", comment: ""))
        Task(priority: .background) {
            do {
                let wm = WalletsRepository.shared.getOrAdd(for: currentAccount)
                let pinData = try self.account.auth(usingAuth)
                let pin = withPIN ?? pinData.plaintextBiometric ?? ""
                _ = try await wm.loginWithPin(pin: pin, pinData: pinData, bip39passphrase: bip39passphrase)
                if withPIN != nil {
                    currentAccount.attempts = 0
                }
                AccountsRepository.shared.current = currentAccount
                success(withPIN: withPIN != nil, account: currentAccount)
            } catch {
                failure(error: error, enableFailingCounter: true)
            }
        }
    }

    @MainActor
    func success(withPIN: Bool, account: Account) {
        self.startLoader(message: NSLocalizedString("id_loading_wallet", comment: ""))
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
            return
        case AuthenticationTypeHandler.AuthError.KeychainError:
            return self.onBioAuthError(error.localizedDescription)
        case AuthenticationTypeHandler.AuthError.SecurityError(let desc):
            DropAlert().error(message: desc.localized)
        case LoginError.connectionFailed:
            DropAlert().error(message: "id_connection_failed".localized)
        case LoginError.walletNotFound:
            let msg = "id_wallet_not_found"
            DropAlert().error(message: msg.localized)
            showReportError(account: account, wallet: nil, prettyError: msg.localized, screenName: "Login")
        case GaError.NotAuthorizedError(_):
            self.wrongPin()
        case TwoFactorCallError.failure(let msg):
            if msg.contains("id_connection_failed") {
                DropAlert().error(message: msg.localized)
            } else if msg.contains("login failed") || msg.contains("id_invalid_pin") {
                let prettyError = "id_invalid_pin"
                if enableFailingCounter {
                    wrongPin()
                }
            } else {
                showReportError(account: account, wallet: nil, prettyError: msg.localized, screenName: "Login")
                DropAlert().error(message: msg.localized)
                AnalyticsManager.shared.failedWalletLogin(account: self.account, error: error, prettyError:  msg.localized)
            }
        default:
            let msg = "id_login_failed"
            showReportError(account: account, wallet: nil, prettyError: msg.localized, screenName: "Login")
            DropAlert().error(message: msg.localized)
        }
        self.pinCode = ""
        self.reloadPin()
    }

    @IBAction func emergencyClick(_ sender: Any) {
        emergencyRestore = false
    }

    func wrongPin() {
        account?.attempts += 1
        AccountsRepository.shared.upsert(account)
        if account?.attempts == self.MAXATTEMPTS {
            WalletsRepository.shared.delete(for: account)
            self.reload()
        } else {
            self.pinCode = ""
            self.updateAttemptsLabel()
            self.reloadPin()
        }
    }

    func onBioAuthError(_ message: String) {
        let text = String(format: NSLocalizedString("id_syou_need_ton1_reset_greens", comment: ""), message)
        let alert = UIAlertController(title: NSLocalizedString("id_warning", comment: ""), message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .default) { _ in })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_reset", comment: ""), style: .destructive) { _ in
            self.account?.removeBioKeychainData()
        })
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }

    func reload() {
        if account.isDerivedLightning {
            [cardEnterPin, cardWalletLock, btnsStack].forEach{
                $0?.isHidden = true
            }
            cardLoginShortcut.isHidden = false
            return
        }
        let showLockPage = !emergencyRestore && (account?.attempts ?? 0 >= self.MAXATTEMPTS  || account?.hasPin == false)
        cardEnterPin.isHidden = showLockPage
        lblTitle.isHidden = showLockPage
        cardWalletLock.isHidden = !showLockPage
        attempts.isHidden = emergencyRestore || account?.attempts == 0
        attemptsView.isHidden = emergencyRestore || account?.attempts == 0
    }

    func updateAttemptsLabel() {
        let pinattempts = account?.attempts ?? 0
        if pinattempts == MAXATTEMPTS {
            reload()
        } else if MAXATTEMPTS - pinattempts == 1 {
            attempts.text = NSLocalizedString("id_last_attempt_if_failed_you_will", comment: "")
        } else {
            attempts.text = String(format: NSLocalizedString("id_attempts_remaining_d", comment: ""), MAXATTEMPTS - pinattempts)
        }
        attempts.isHidden = emergencyRestore || pinattempts == 0
        attemptsView.isHidden = emergencyRestore || pinattempts == 0
    }

    @objc func keyClick(sender: UIButton) {
        pinCode += (sender.titleLabel?.text)!
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

    @objc func click(sender: UIButton) {
        if sender == deleteButton {
            if pinCode.count > 0 {
                pinCode.removeLast()
            }
        } else if sender == cancelButton {
            pinCode = ""
        }
        reloadPin()
    }

    @IBAction func clickLoginLightningShortcut(_ sender: Any) {
        loginWithLightningShortcut()
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
        let alert = UIAlertController(title: NSLocalizedString("Emergency Recovery Phrase Restore", comment: ""),
                                      message: NSLocalizedString("If for any reason you can't login into your wallet, you can recover your recovery phrase using your PIN/Biometrics.", comment: ""),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { (_: UIAlertAction) in })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_ok", comment: ""), style: .default) { (_: UIAlertAction) in
            self.emergencyRestore = true
            self.reload()
            if self.account.hasBioPin {
                self.loginWithPin(usingAuth: .AuthKeyBiometric, withPIN: nil, bip39passphrase: nil)
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
        OnBoardParams.shared = OnBoardParams(testnet: account?.gdkNetwork.mainnet,
                                             walletName: account?.name,
                                             accountId: account?.id ?? UUID().uuidString,
                                             xpubHashId: account?.xpubHashId ?? "")
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
        self.account?.name = name
        if let account = self.account {
            AccountsRepository.shared.upsert(account)
            navigationItem.title = account.name
            AnalyticsManager.shared.renameWallet()
        }
    }
    func didDelete(_ index: String?) {
        if let account = self.account {
            AccountsRepository.shared.remove(account)
            navigationController?.popViewController(animated: true)
            AnalyticsManager.shared.deleteWallet()
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
        account.askEphemeral = alwaysAsk
        AccountsRepository.shared.upsert(account)
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
