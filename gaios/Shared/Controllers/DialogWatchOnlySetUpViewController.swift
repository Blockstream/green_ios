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

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var btnsStackBottom: NSLayoutConstraint!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var btnSave: UIButton!
    @IBOutlet weak var btnDelete: UIButton!
    @IBOutlet weak var lblUsernameError: UILabel!
    @IBOutlet weak var lblPasswordError: UILabel!
    @IBOutlet weak var btnSecure: UIButton!

    weak var delegate: DialogWatchOnlySetUpViewControllerDelegate?

    var account = { AccountsRepository.shared.current }()
    var buttonConstraint: NSLayoutConstraint?
    var session: SessionManager!
    var username: String?
    var preDeleteFlag = false

    lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .dark)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.4)
        customBlurEffectView.frame = self.view.bounds

        let dimmedView = UIView()
        dimmedView.backgroundColor = .black.withAlphaComponent(0.3)
        dimmedView.frame = self.view.bounds
        containerView.addSubview(customBlurEffectView)
        containerView.addSubview(dimmedView)
        return containerView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)
        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            swipeDown.direction = .down
            self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTap))
            tappableBg.addGestureRecognizer(tapToClose)

        passwordField.isSecureTextEntry = true
        updateSecureBtn()
        AnalyticsManager.shared.recordView(.watchOnlyCredentials)
        load()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
        usernameField.becomeFirstResponder()
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
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.titleCard)
        lblHint.setStyle(.txtCard)
        btnDelete.setStyle(.destructiveOutlined)
        usernameField.setLeftPaddingPoints(10.0)
        usernameField.setRightPaddingPoints(10.0)
        passwordField.setLeftPaddingPoints(10.0)
        passwordField.setRightPaddingPoints(10.0)
    }
    func updateSecureBtn() {
        let img = passwordField.isSecureTextEntry == true ? UIImage(named: "ic_eye")!.maskWithColor(color: UIColor.gAccent()) : UIImage(named: "ic_hide")!.maskWithColor(color: UIColor.gAccent())
        btnSecure.setImage(img, for: .normal)
    }
    @objc func didTap(gesture: UIGestureRecognizer) {

        dismiss(.cancel)
    }
    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)

        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            self.btnsStackBottom.constant = keyboardFrame.height
        })
    }
    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.btnsStackBottom.constant = 36.0
        })
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
    func dismiss(_ action: WatchOnlySetUpAction) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            switch action {
            case .cancel:
                break
            case .save, .delete:
                self.delegate?.watchOnlyDidUpdate(action)
            }
        })
    }
    @objc func didSwipe(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss(.cancel)
            default:
                break
            }
        }
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
