import Foundation
import UIKit
import core

class SetEmailViewController: KeyboardViewController {

    @IBOutlet weak var headerTitle: UILabel!
    @IBOutlet weak var setRecoveryLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!

    private var viewModel: Set2FAViewModel
    weak var coordinator: SettingsCoordinator?
    var isSetRecovery: Bool { viewModel.isSetRecovery }

    init?(coder: NSCoder, viewModel: Set2FAViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        headerTitle.text = "id_enter_your_email_address".localized
        textField.attributedPlaceholder = NSAttributedString(string: "email@domain.com",
                                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.6)])
        textField.setLeftPaddingPoints(10.0)
        textField.setRightPaddingPoints(10.0)
        nextButton.setTitle("id_get_code".localized, for: .normal)
        nextButton.addTarget(self, action: #selector(click), for: .touchUpInside)
        nextButton.setStyle(.primaryDisabled)
        setRecoveryLabel.text = isSetRecovery ?
            "id_set_up_an_email_to_get".localized :
            "id_the_email_will_also_be_used_to".localized
        headerTitle.font = UIFont.systemFont(ofSize: 24.0, weight: .bold)
        setRecoveryLabel.font = UIFont.systemFont(ofSize: 12.0, weight: .regular)
        setRecoveryLabel.textColor = .white.withAlphaComponent(0.6)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    override func keyboardWillShow(notification: Notification) {
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        buttonConstraint.constant = keyboardFrame.height
    }

    @objc func click(_ sender: UIButton) {
        guard let text = textField.text else { return }
        view.endEditing(true)
        self.startAnimating()
        Task { [weak self] in
            do {
                let config = TwoFactorConfigItem(enabled: self?.isSetRecovery ?? false ? false : true, confirmed: true, data: text)
                let params = ChangeSettingsTwoFactorParams(method: .email, config: config)
                try await self?.viewModel.changeSettingsTwoFactor(params)
                self?.stopAnimating()
                if let coordinator = self?.coordinator {
                    coordinator.pop()
                } else {
                    self?.navigationController?.popViewController(animated: true)
                }
            } catch {
                self?.stopAnimating()
                DropAlert()
                    .error(message: error.description().localized)
            }
        }
    }

    @IBAction func editingChanged(_ sender: Any) {
        (textField.text ?? "").isValidEmailAddr() ? nextButton.setStyle(.primary) : nextButton.setStyle(.primaryDisabled)
    }
}
