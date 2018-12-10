
import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class WatchOnlySettings: KeyboardViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_set_watchonly", comment: "")
        usernameTextField.attributedPlaceholder = NSAttributedString(string: "Username",
                                                                     attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        passwordTextField.attributedPlaceholder = NSAttributedString(string: "Password",
                                                                     attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        usernameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: usernameTextField.frame.height))
        passwordTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: passwordTextField.frame.height))
        usernameTextField.leftViewMode = .always
        passwordTextField.leftViewMode = .always
        saveButton.setTitle(NSLocalizedString("id_save", comment: ""), for: .normal)
    }

    @IBAction func saveClicked(_ sender: Any) {
        let username = usernameTextField.text!
        let password = passwordTextField.text!

        firstly {
            startAnimating()
            return Guarantee()
        }.compactMap {
            try getGAService().getSession().setWatchOnly(username: username, password: password)
        }.ensure {
            self.stopAnimating()
        }.done {
            self.navigationController?.popViewController(animated: true)
        }.catch { error in
        }
    }
}
