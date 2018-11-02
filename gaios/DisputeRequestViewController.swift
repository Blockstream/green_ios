import Foundation
import UIKit

class DisputeRequestViewController : UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var disputeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = NSLocalizedString("id_dispute_twofactor_reset", comment: "")
        warningLabel.text = NSLocalizedString("id_warning_there_is_already_a", comment: "")
        disputeButton.setTitle(NSLocalizedString("id_dispute_twofactor_reset", comment: ""), for: .normal)
        emailTextField.attributedPlaceholder = NSAttributedString(string: "email@domain.com",
                                                                  attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        hideKeyboardWhenTappedAround()
    }

    @IBAction func disputeButtonClicked(_ sender: Any) {
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

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
        }

        if let nextController = segue.destination as? TwoFactorSlectorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
        }
    }

}
