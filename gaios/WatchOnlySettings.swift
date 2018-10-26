
import Foundation
import UIKit
import NVActivityIndicatorView

class WatchOnlySettings: UIViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var warningLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        warningLabel.isHidden = true
        topLabel.text = NSLocalizedString("id_set_watchonly", comment: "")
        usernameTextField.attributedPlaceholder = NSAttributedString(string: "Username",
                                                                     attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        passwordTextField.attributedPlaceholder = NSAttributedString(string: "Password",
                                                                     attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        usernameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: usernameTextField.frame.height))
        passwordTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: passwordTextField.frame.height))
        usernameTextField.leftViewMode = .always
        passwordTextField.leftViewMode = .always
        saveButton.setTitle(NSLocalizedString("id_save", comment: ""), for: .normal)
        warningLabel.text = NSLocalizedString("id_warning_password_must_be_at", comment: "")
        hideKeyboardWhenTappedAround()
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    func showWarning() {
        warningLabel.isHidden = false
    }

    func hideWarning() {
        warningLabel.isHidden = true
    }

    @IBAction func saveClicked(_ sender: Any) {
        let username = usernameTextField.text!
        let password = passwordTextField.text!
        if(password.count < 8) {
            showWarning()
            return
        }
        wrap {
            try getSession().setWatchOnly(username: username, password: password)
        }.done {
            self.hideWarning()
            let size = CGSize(width: 30, height: 30)
            let message = NSLocalizedString("id_done", comment: "")
            self.startAnimating(size, message: message, messageFont: nil, type: NVActivityIndicatorType.blank)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                self.stopAnimating()
            }
        }.catch { error in
            let size = CGSize(width: 30, height: 30)
            let message = NSLocalizedString("id_something_went_wrong", comment: "")
            self.startAnimating(size, message: message, messageFont: nil, type: NVActivityIndicatorType.blank)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                self.stopAnimating()
            }
        }
    }
}
