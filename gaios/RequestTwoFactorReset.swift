import Foundation
import UIKit

class RequestTwoFactorReset : UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        emailTextField.attributedPlaceholder = NSAttributedString(string: "email@domain.com",
                                                                  attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        hideKeyboardWhenTappedAround()
        titleLabel.text = NSLocalizedString("prequest_two_factor_reset", comment: "")
        emailLabel.text = NSLocalizedString("penter_new_email", comment: "")
        warningLabel.text = NSLocalizedString("pwarning_resetting_two_factor", comment: "")
        requestButton.setTitle(NSLocalizedString("prequest", comment: ""), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func requestClicked(_ sender: Any) {
        if let email = emailTextField.text {
            do {
                let factor =  try getSession().resetTwoFactor(email: email, isDispute: true)
                let json = try factor.getStatus()
                let status = json!["status"] as! String
                if (status == "call") {
                    let call = try factor.call()
                    let json_call = try factor.getStatus()
                    let status_call = json_call!["status"] as! String
                    if (status_call == "resolve_code") {
                        self.performSegue(withIdentifier: "verifyCode", sender: factor)
                    }
                }
            } catch {
                print("something went wrong")
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
        }
    }

}
