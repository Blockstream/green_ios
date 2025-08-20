import Foundation
import UIKit
import core
import gdk

enum SecurityOption: String {
    case single = "SingleSig"
    case multi = "MultiSig"
}

class WOSetupViewController: KeyboardViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var btnSettings: UIButton!
    @IBOutlet weak var lblUsername: UILabel!
    @IBOutlet weak var lblPassword: UILabel!
    @IBOutlet weak var remView: UIView!
    @IBOutlet weak var iconRem: UIImageView!
    @IBOutlet weak var btnRem: UIButton!
    @IBOutlet weak var lblRem: UILabel!

    private var buttonConstraint: NSLayoutConstraint?
    private var progressToken: NSObjectProtocol?
    private let viewModel = WOViewModel()
    private var isRem: Bool = false
    var network: NetworkSecurityCase!

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        refresh()

        loginButton.addTarget(self, action: #selector(click), for: .touchUpInside)
        usernameTextField.addDoneButtonToKeyboard(myAction: #selector(self.usernameTextField.resignFirstResponder))
        passwordTextField.addDoneButtonToKeyboard(myAction: #selector(self.usernameTextField.resignFirstResponder))
        AnalyticsManager.shared.recordView(.onBoardWatchOnlyCredentials)
    }

    func setContent() {
        lblTitle.text = "id_login".localized
        lblHint.text = "id_log_in_via_watchonly_to_receive".localized
        warningLabel.text = "id_watchonly_mode_can_be_activated".localized
        loginButton.setTitle("id_log_in".localized, for: .normal)
        lblUsername.text = "id_username".localized
        lblPassword.text = "id_password".localized
        lblRem.text = "id_remember_me".localized
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txt)
        warningLabel.setStyle(.txt)
        lblUsername.setStyle(.sectionTitle)
        lblPassword.setStyle(.sectionTitle)
        warningLabel.textColor = UIColor.gW40()
        loginButton.setStyle(.primary)
        btnSettings.setTitle("id_app_settings".localized, for: .normal)
        usernameTextField.setLeftPaddingPoints(10.0)
        usernameTextField.setRightPaddingPoints(10.0)
        passwordTextField.setLeftPaddingPoints(10.0)
        passwordTextField.setRightPaddingPoints(10.0)
        usernameTextField.leftViewMode = .always
        passwordTextField.leftViewMode = .always
        usernameTextField.layer.cornerRadius = 5.0
        passwordTextField.layer.cornerRadius = 5.0
        remView.borderWidth = 1.0
        remView.borderColor = .white.withAlphaComponent(0.7)
        remView.layer.cornerRadius = 5.0
        [usernameTextField, passwordTextField].forEach {
            $0?.setStyle(CardStyle.defaultStyle)
        }
    }

    func refresh() {
        iconRem.image = isRem ? UIImage(named: "ic_checkbox_on")! : UIImage(named: "ic_checkbox_off")!
    }

    @objc func rememberSwitchChange(_ sender: UISwitch) {
        if sender.isOn {
            let alert = UIAlertController(title: "id_warning_watchonly_credentials".localized, message: "id_your_watchonly_username_and".localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { _ in
                sender.isOn = false
            })
            alert.addAction(UIAlertAction(title: "id_ok".localized, style: .default) { _ in
                sender.isOn = true
            })
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    @objc func testnetSwitchChange(_ sender: UISwitch) {
    }

    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
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

    @objc func click(_ sender: Any) {
        login(for: network)
    }

    @IBAction func btnRem(_ sender: Any) {
        isRem = !isRem
        refresh()
    }

    @IBAction func btnSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func login(for network: NetworkSecurityCase) {
        let account = viewModel.newAccountMultisig(
            for: network.gdkNetwork,
            username: self.usernameTextField.text ?? "",
            password: isRem ? self.passwordTextField.text ?? "" : "",
            remember: isRem)
        dismissKeyboard()
        self.startLoader(message: "id_logging_in".localized)
        Task {
            do {
                try await self.viewModel.loginMultisig(for: account, password: self.passwordTextField.text)
                success(account: account)
            } catch {
                failure(error, account: account)
            }
        }
    }

    @MainActor
    func success(account: Account) {
        stopLoader()
        AccountNavigator.navLogged(accountId: account.id)
    }

    @MainActor
    func failure(_ error: Error, account: Account) {
        var prettyError = "id_login_failed"
        switch error {
        case TwoFactorCallError.failure(let localizedDescription):
            prettyError = localizedDescription
        case LoginError.connectionFailed:
            prettyError = "id_connection_failed"
        case LoginError.failed:
            prettyError = "id_login_failed"
        default:
            break
        }
        stopLoader()
        DropAlert().error(message: prettyError.localized)
        AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: prettyError)
        WalletsRepository.shared.delete(for: account)
    }
}
