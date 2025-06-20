import Foundation
import LocalAuthentication
import UIKit
import core
import gdk

class WOLoginViewController: KeyboardViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblUsername: UILabel!
    @IBOutlet weak var lblPassword: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginMSButton: UIButton!
    @IBOutlet weak var loginSSButton: UIButton!
    @IBOutlet weak var btnSettings: UIButton!
    @IBOutlet weak var ssModeView: UIView!
    @IBOutlet weak var msModeView: UIView!

    var account: Account!
    private var buttonConstraint: NSLayoutConstraint?
    private var progressToken: NSObjectProtocol?
    private let viewModel = WOViewModel()
    let menuButton = UIButton(type: .system)
    var isSS: Bool { account.gdkNetwork.electrum }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = account?.name ?? ""

        ssModeView.isHidden = !isSS
        msModeView.isHidden = isSS

        setContent()
        setStyle()

        menuButton.setImage(UIImage(named: "ellipses"), for: .normal)
        menuButton.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: menuButton)

        loginMSButton.addTarget(self, action: #selector(click), for: .touchUpInside)
        loginSSButton.addTarget(self, action: #selector(click), for: .touchUpInside)
        usernameTextField.addDoneButtonToKeyboard(myAction: #selector(self.usernameTextField.resignFirstResponder))
        passwordTextField.addDoneButtonToKeyboard(myAction: #selector(self.usernameTextField.resignFirstResponder))

        if let username = account?.username {
            usernameTextField.text = username
        }
        if let password = account?.password {
            passwordTextField.text = password
        }
    }

    func setContent() {
        lblTitle.text = "id_log_in_via_watchonly_to_receive".localized
        lblHint.text = ""
        lblUsername.text = "id_username".localized
        lblPassword.text = "id_password".localized
        loginMSButton.setTitle("id_log_in".localized, for: .normal)
        loginSSButton.setTitle("id_log_in".localized, for: .normal)
        btnSettings.setTitle("id_app_settings".localized, for: .normal)
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txt)
        lblUsername.setStyle(.sectionTitle)
        lblPassword.setStyle(.sectionTitle)
        loginMSButton.setStyle(.primary)
        loginSSButton.setStyle(.primary)

        usernameTextField.setLeftPaddingPoints(10.0)
        usernameTextField.setRightPaddingPoints(10.0)
        passwordTextField.setLeftPaddingPoints(10.0)
        passwordTextField.setRightPaddingPoints(10.0)
        usernameTextField.layer.cornerRadius = 5.0
        passwordTextField.layer.cornerRadius = 5.0
        usernameTextField.leftViewMode = .always
        passwordTextField.leftViewMode = .always
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        progressToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: EventType.Tor.rawValue), object: nil, queue: .main, using: progress)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = progressToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    @objc func menuButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {

            vc.viewModel = DialogListViewModel(title: "More Options", type: .loginPrefs, items: LoginPrefs.getItems(isWatchOnly: true))
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @objc func progress(_ notification: Notification) {
        if let json = try? JSONSerialization.data(withJSONObject: notification.userInfo!, options: []),
           let tor = try? JSONDecoder().decode(TorNotification.self, from: json) {
            var text = "id_tor_status".localized + " \(tor.progress)%"
            if tor.progress == 100 {
                text = "id_logging_in".localized
            }
            DispatchQueue.main.async {
                self.startLoader(message: text)
            }
        }
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillShow(notification: notification)
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
            vc.index = nil
            vc.delegate = self
            vc.prefill = account.name
            present(vc, animated: false, completion: nil)
        }
    }

    func authenticated() async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authentication")
        }
        return false
    }

    func hasBiometricAuthenticationType() -> Bool {
        if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoBioCredentials, forNetwork: account.keychain) {
            return true
        } else if AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: account.keychain) {
            return true
        } else {
            return false
        }
    }

    func loginSinglesig() async throws {
        if hasBiometricAuthenticationType() {
            try await viewModel.loginSinglesig(for: self.account)
            return
        }
        switch AuthenticationTypeHandler.biometryType {
        case .faceID, .touchID:
            let evaluate = try? await authenticated()
            if evaluate ?? false {
                try await viewModel.loginSinglesig(for: self.account)
            } else {
                throw AuthenticationTypeHandler.AuthError.DeniedByUser
            }
        default:
            try await viewModel.loginSinglesig(for: self.account)
        }
    }

    func loginMultisig() async throws {
        let password = self.passwordTextField.text ?? ""
        try await self.viewModel.loginMultisig(for: self.account, password: password)
    }

    func login() async {
        dismissKeyboard()
        startLoader(message: "id_logging_in".localized)
        let task = Task.detached { [weak self] in
            if await self?.isSS ?? false {
                try await self?.loginSinglesig()
            } else {
                try await self?.loginMultisig()
            }
        }
        switch await task.result {
        case .success:
            stopLoader()
            AccountNavigator.navLogged(accountId: account.id)
            AnalyticsManager.shared.importWallet(account: account)
        case .failure(let error):
            stopLoader()
            showError(error)
            AnalyticsManager.shared.failedWalletLogin(account: self.account, error: error, prettyError: error.description())
            WalletsRepository.shared.delete(for: self.account)
        }
    }

    @objc func click(_ sender: Any) {
        view.endEditing(true)
        Task { [weak self] in
            await self?.login()
        }
    }

    @IBAction func btnSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController")
        navigationController?.pushViewController(vc, animated: true)
    }

}

extension WOLoginViewController: DialogRenameViewControllerDelegate, DialogDeleteViewControllerDelegate {
    func didRename(name: String, index: String?) {
        account?.name = name
        if let account = self.account {
            AccountsRepository.shared.upsert(account)
            navigationItem.title = account.name
            AnalyticsManager.shared.renameWallet()
        }
    }
    func didDelete(_ index: String?) {
        if let account = self.account {
            Task {
                await AccountsRepository.shared.remove(account)
                await MainActor.run {
                    navigationController?.popViewController(animated: true)
                    AnalyticsManager.shared.deleteWallet()
                }
            }
        }
    }
    func didCancel() {
    }
}

extension WOLoginViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }
}

extension WOLoginViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .loginPrefs:
            switch index {
            case 0:
                walletRename()
            case 1:
                walletDelete()
            default:
                break
            }
        default:
            break
        }
    }
}
