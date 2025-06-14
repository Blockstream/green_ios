import Foundation
import UIKit
import core
import gdk
import greenaddress

protocol DialogWatchOnlySetUpViewControllerDelegate: AnyObject {
    func watchOnlyDidUpdate(_ action: WatchOnlySetUpAction)
}

enum WatchOnlySetUpAction {
    case save
    case delete
    case cancel
}

class DialogWatchOnlySetUpViewController: KeyboardViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var btnSave: UIButton!
    @IBOutlet weak var btnDelete: UIButton!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var btnsStack: UIStackView!
    @IBOutlet weak var lblUsernameError: UILabel!
    @IBOutlet weak var lblPasswordError: UILabel!
    @IBOutlet weak var btnSecure: UIButton!

    weak var delegate: DialogWatchOnlySetUpViewControllerDelegate?

    var account = { AccountsRepository.shared.current }()
    var buttonConstraint: NSLayoutConstraint?
    var session: SessionManager!
    var username: String?
    var preDeleteFlag = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        view.alpha = 0.0

        passwordField.isSecureTextEntry = true
        updateSecureBtn()

        view.accessibilityIdentifier = AccessibilityIdentifiers.DialogWatchOnlySetUpScreen.view
        usernameField.accessibilityIdentifier = AccessibilityIdentifiers.DialogWatchOnlySetUpScreen.usernameField
        passwordField.accessibilityIdentifier = AccessibilityIdentifiers.DialogWatchOnlySetUpScreen.passwordField
        btnSave.accessibilityIdentifier = AccessibilityIdentifiers.DialogWatchOnlySetUpScreen.saveBtn
        btnDelete.accessibilityIdentifier = AccessibilityIdentifiers.DialogWatchOnlySetUpScreen.deleteBtn
        btnDismiss.accessibilityIdentifier = AccessibilityIdentifiers.DialogWatchOnlySetUpScreen.dismissBtn

        AnalyticsManager.shared.recordView(.watchOnlyCredentials)
        load()
    }

    func setContent() {
        lblTitle.text = "id_watchonly_credentials".localized
        lblHint.text = "id_allows_you_to_quickly_check".localized
        btnDelete.setTitle("id_delete_credentials".localized, for: .normal)
        usernameField.attributedPlaceholder = NSAttributedString(string: "id_username".localized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        passwordField.attributedPlaceholder = NSAttributedString(string: "id_password".localized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        lblUsernameError.text = "id_at_least_8_characters_required".localized
        lblPasswordError.text = "id_at_least_8_characters_required".localized
    }

    func setStyle() {
        btnDelete.setStyle(.destructiveOutlined)
        usernameField.setLeftPaddingPoints(10.0)
        usernameField.setRightPaddingPoints(10.0)
        passwordField.setLeftPaddingPoints(10.0)
        passwordField.setRightPaddingPoints(10.0)
        cardView.setStyle(.bottomsheet)
    }

    func updateSecureBtn() {
        let img = passwordField.isSecureTextEntry == true ? UIImage(named: "ic_eye")!.maskWithColor(color: UIColor.gAccent()) : UIImage(named: "ic_hide")!.maskWithColor(color: UIColor.gAccent())
        btnSecure.setImage(img, for: .normal)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
        usernameField.becomeFirstResponder()
    }

    func updateWatchOnly(username: String, password: String, action: WatchOnlySetUpAction) {
        startAnimating()
        Task {
            do {
                try await session.register(credentials: Credentials(username: username, password: password))
                load()
                dismiss(action)
            } catch {
                switch error {
                case GaError.ReconnectError(let msg),
                    GaError.TimeoutError(let msg),
                    GaError.SessionLost(let msg),
                    GaError.GenericError(let msg):
                    self.showError(msg ?? "id_error")
                default:
                    self.showError(error.localizedDescription)
                }
            }
        }
        stopAnimating()
    }

    func load() {
        Task {
            username = try? await session.getWatchOnlyUsername()
            if username != "" {
                self.btnSave.setTitle("id_update".localized, for: .normal)
                self.usernameField.text = username
            } else {
                self.btnSave.setTitle("id_save".localized, for: .normal)
                self.btnDelete.isHidden = true
            }
            self.validate()
        }
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.buttonConstraint?.isActive = false
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            self.buttonConstraint = self.btnsStack.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -keyboardFrame.height - 14.0)
            self.buttonConstraint?.isActive = true
        })
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.buttonConstraint?.isActive = false
        })
    }

    func dismiss(_ action: WatchOnlySetUpAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            switch action {
            case .save, .delete:
                self.delegate?.watchOnlyDidUpdate(action)
            case .cancel:
                break
            }
        })
    }

    func validate() {

        lblUsernameError.isHidden = true
        lblPasswordError.isHidden = true

        btnSave.setStyle(.primaryDisabled)
        btnSave.isEnabled = false

        if let username = usernameField.text, let password = passwordField.text {

            if usernameField.isFirstResponder {
                if username.count < 8 {
                    lblUsernameError.isHidden = false
                }
            }

            if passwordField.isFirstResponder {
                if password.count < 8 {
                    lblPasswordError.isHidden = false
                }
            }

            if username.count >= 8, password.count >= 8 {
                btnSave.setStyle(.primary)
                btnSave.isEnabled = true
            }
        }
    }

    @IBAction func btnSave(_ sender: Any) {

        if let username = usernameField.text, let password = passwordField.text {
            // first validate
            if username.isEmpty {
                self.showAlert(title: "id_error".localized, message: "id_enter_a_valid_username".localized)
                return
            } else if password.isEmpty {
                self.showAlert(title: "id_error".localized, message: "id_the_password_cant_be_empty".localized)
                return
            }
            updateWatchOnly(username: username, password: password, action: .save)
        }
    }

    @IBAction func btnDelete(_ sender: Any) {

        if preDeleteFlag {
            updateWatchOnly(username: "", password: "", action: .delete)
        } else {
            preDeleteFlag = true
            btnDelete.backgroundColor = UIColor.customDestructiveRed()
            btnDelete.setTitleColor(.white, for: .normal)
        }
    }

    @IBAction func btnDismiss(_ sender: Any) {

        dismiss(.cancel)
    }

    @IBAction func usernameDidChange(_ sender: Any) {
        validate()
    }

    @IBAction func passwordDidChange(_ sender: Any) {
        validate()
    }

    @IBAction func btnSecure(_ sender: Any) {
        passwordField.isSecureTextEntry.toggle()
        updateSecureBtn()
    }
}
