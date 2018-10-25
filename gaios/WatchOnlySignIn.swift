
import Foundation
import UIKit
import NVActivityIndicatorView

class WatchOnlySignIn: UIViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var titlelabel: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var rememberSwitch: UISwitch!
    @IBOutlet weak var rememberTitle: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var forgotButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        rememberTitle.text = NSLocalizedString("premember_username", comment: "")
        forgotButton.setTitle(NSLocalizedString("pi_forgot_my_password", comment: ""), for: .normal)
        loginButton.setTitle(NSLocalizedString("plog_in", comment: ""), for: .normal)
        titlelabel.text = NSLocalizedString("plog_in_to_receive_funds", comment: "")
        usernameTextField.attributedPlaceholder = NSAttributedString(string: "Username",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        passwordTextField.attributedPlaceholder = NSAttributedString(string: "Password",
                                                                     attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        usernameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: usernameTextField.frame.height))
        passwordTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: passwordTextField.frame.height))
        usernameTextField.leftViewMode = .always
        passwordTextField.leftViewMode = .always
    }

    @IBAction func loginButtonClicked(_ sender: Any) {
        let size = CGSize(width: 30, height: 30)
        let message = NSLocalizedString("plogging_in_please_wait", comment: "")
        startAnimating(size, message: message, messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)

        let username = usernameTextField.text
        let password = passwordTextField.text

        wrap{
            try getSession().loginWatchOnly(username: username!, password: password!)
        }.done{
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.7) {
                self.stopAnimating()
                AccountStore.shared.initializeAccountStore()
                self.performSegue(withIdentifier: "main", sender: nil)
            }
        }.catch { error in
            DispatchQueue.main.async{
                let message = NSLocalizedString("plogin_failed", comment: "")
                NVActivityIndicatorPresenter.sharedInstance.setMessage(message)
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.7) {
                self.stopAnimating()
            }
        }
    }

    @IBAction func forgotMyPasswordClicked(_ sender: Any) {
        DispatchQueue.main.async{
            let message = NSLocalizedString("plog_in_using_seed", comment: "")
            let size = CGSize(width: 30, height: 30)
            self.startAnimating(size, message: message, messageFont: nil, type: NVActivityIndicatorType.blank)
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
            self.stopAnimating()
            self.performSegue(withIdentifier: "enterMnemonics", sender: "")
        }
    }

    @IBAction func cacnelButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

}
