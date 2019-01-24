
import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class WatchOnlySignIn: KeyboardViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var titlelabel: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var rememberSwitch: UISwitch!
    @IBOutlet weak var rememberTitle: UILabel!
    @IBOutlet weak var loginButton: UIButton!

    var username: String? {
        get {
            return UserDefaults.standard.string(forKey: getNetwork() + "_username")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: getNetwork() + "_username")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rememberTitle.text = NSLocalizedString("id_remember_username", comment: "")
        loginButton.setTitle(NSLocalizedString("id_log_in", comment: ""), for: .normal)
        titlelabel.text = NSLocalizedString("id_log_in_to_receive_funds_and", comment: "")
        usernameTextField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("id_username", comment: ""),
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        passwordTextField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("id_password", comment: ""),
                                                                     attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        usernameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: usernameTextField.frame.height))
        passwordTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: passwordTextField.frame.height))
        usernameTextField.leftViewMode = .always
        passwordTextField.leftViewMode = .always

        if let _ = username {
            usernameTextField.text = username!
        }
    }

    @IBAction func rememberSwitch(_ sender: UISwitch) {
        if sender.isOn {
            let alert = UIAlertController(title: NSLocalizedString("id_warning_the_username_will_be", comment: ""), message: NSLocalizedString("id_your_watchonly_username_will_be", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { _ in })
                sender.isOn = false
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_ok", comment: ""), style: .default) { _ in
                sender.isOn = true
            })
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    @IBAction func loginButtonClicked(_ sender: Any) {
        let bgq = DispatchQueue.global(qos: .background)
        let appDelegate = getAppDelegate()

        firstly {
            self.startAnimating(message: NSLocalizedString("id_logging_in", comment: ""))
            return Guarantee()
        }.compactMap(on: bgq) {
            try appDelegate.disconnect()
        }.compactMap(on: bgq) {
            try appDelegate.connect()
        }.compactMap {
            let username = self.usernameTextField.text
            let password = self.passwordTextField.text
            self.username = username
            return (username!, password!)
        }.compactMap(on: bgq) { (username, password) in
            try getSession().loginWatchOnly(username: username!, password: password!)
        }.ensure {
            self.stopAnimating()
        }.done {
            AccountStore.shared.isWatchOnly = true
            self.performSegue(withIdentifier: "main", sender: nil)
        }.catch { error in
            let message: String
            if let err = error as? GaError, err != GaError.GenericError {
                message = NSLocalizedString("id_you_are_not_connected_to_the", comment: "")
            } else {
                message = NSLocalizedString("id_login_failed", comment: "")
            }
            self.startAnimating(message: message)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
                self.stopAnimating()
            }
        }
    }
}
