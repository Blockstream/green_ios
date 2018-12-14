
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
    }

    @IBAction func loginButtonClicked(_ sender: Any) {
        let bgq = DispatchQueue.global(qos: .background)

        firstly {
            let size = CGSize(width: 30, height: 30)
            let message = NSLocalizedString("id_logging_in", comment: "")
            startAnimating(size, message: message, messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
            let username = self.usernameTextField.text
            let password = self.passwordTextField.text
            return .value((username!, password!))
        }.compactMap(on: bgq) { (username, password) in
            try getSession().loginWatchOnly(username: username!, password: password!)
        }.done {
            AccountStore.shared.isWatchOnly = true
            AccountStore.shared.initializeAccountStore()
            self.performSegue(withIdentifier: "main", sender: nil)
        }.catch { error in
            DispatchQueue.main.async{
                let message = NSLocalizedString("id_login_failed", comment: "")
                NVActivityIndicatorPresenter.sharedInstance.setMessage(message)
            }
        }.finally {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.7) {
                self.stopAnimating()
            }
        }
    }
}
