
import Foundation
import UIKit

class WatchOnlySignIn: UIViewController {

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

}
