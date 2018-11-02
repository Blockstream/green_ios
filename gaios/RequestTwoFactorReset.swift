import Foundation
import UIKit

class RequestTwoFactorReset : UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!
    @IBOutlet weak var disputeButton: UIButton!
    var isReset = false
    override func viewDidLoad() {
        super.viewDidLoad()
        emailTextField.attributedPlaceholder = NSAttributedString(string: "email@domain.com",
                                                                  attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        hideKeyboardWhenTappedAround()
        titleLabel.text = NSLocalizedString("id_request_twofactor_reset", comment: "")
        emailLabel.text = NSLocalizedString("id_enter_new_email", comment: "")
        warningLabel.text = NSLocalizedString("id_warning_resetting_twofactor", comment: "")
        requestButton.setTitle(NSLocalizedString("id_request", comment: ""), for: .normal)
        NotificationCenter.default.addObserver(self, selector: #selector(self.resetChanged(_:)), name: NSNotification.Name(rawValue: "twoFactorReset"), object: nil)
    }

    func updateUI() {
        let data = AccountStore.shared.getTwoFactorResetData()
        if (data.isReset) {
            isReset = true
            disputeButton.isHidden = false
            warningLabel.text = NSLocalizedString("id_two_factor_reset_is_in_progress", comment: "")
            disputeButton.setTitle(NSLocalizedString("id_dispute_twofactor_reset", comment: ""), for: .normal)
            requestButton.setTitle(NSLocalizedString("id_cancel_twofactor_reset", comment: ""), for: .normal)
            emailLabel.isHidden = true
            emailTextField.isHidden = true
        } else {
            isReset = false
            disputeButton.isHidden = true
            requestButton.setTitle(NSLocalizedString("id_request", comment: ""), for: .normal)
        }
    }

    @objc func resetChanged(_ notification: NSNotification) {
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func disputeButtonClicekd(_ sender: Any) {
        self.performSegue(withIdentifier: "disputeRequest", sender: nil)
    }

    @IBAction func requestClicked(_ sender: Any) {
        if (isReset) {
            do {
                let factor = try getSession().cancelTwoFactorReset()
                let json = try factor.getStatus()
                let status = json!["status"] as! String
                if (status == "request_code") {
                    let methods = json!["methods"] as! NSArray
                    if (methods.count == 1) {
                        let met = methods[0] as! String
                        let request = try factor.requestCode(method: met)
                        self.performSegue(withIdentifier: "verifyCode", sender: factor)
                    } else {
                        self.performSegue(withIdentifier: "selectTwoFactor", sender: factor)
                    }
                }
            } catch {
            }
        } else {
            if let email = emailTextField.text {
                do {
                    let factor =  try getSession().resetTwoFactor(email: email, isDispute: false)
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
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
            nextController.popToRoot = false
        }
        if let nextController = segue.destination as? TwoFactorSlectorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
        }
    }

}
