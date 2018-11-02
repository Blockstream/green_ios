import Foundation
import UIKit

class DisputeRequestViewController : UIViewController, TwoFactorCallDelegate {

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
            DispatchQueue.global(qos: .background).async {
                wrap {
                    try getSession().resetTwoFactor(email: email, isDispute: true)
                    }.done { (result: TwoFactorCall?) in
                        do {
                            let resultHelper = TwoFactorCallHelper(result!)
                            resultHelper.delegate = self
                            try resultHelper.resolve()
                        } catch {
                            print(error)
                        }
                    } .catch { error in
                        print(error)
                }
            }
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    func onResolve(_ sender: TwoFactorCallHelper) {
        let alert = TwoFactorCallHelper.CodePopup(sender)
        alert.onboarding = false
        self.present(alert, animated: true, completion: nil)
    }

    func onRequest(_ sender: TwoFactorCallHelper) {
        let selector = TwoFactorCallHelper.MethodPopup(sender)
        self.present(selector, animated: true, completion: nil)
    }

    func onDone(_ sender: TwoFactorCallHelper) {
        self.navigationController?.popViewController(animated: true)
    }

    func onError(_ sender: TwoFactorCallHelper, text: String) {
    }
}
