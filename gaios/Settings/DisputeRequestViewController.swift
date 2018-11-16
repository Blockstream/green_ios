import Foundation
import UIKit
import NVActivityIndicatorView

class DisputeRequestViewController : UIViewController, NVActivityIndicatorViewable, TwoFactorCallDelegate {

    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var disputeButton: UIButton!
    var errorLabel: UIErrorLabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_dispute_twofactor_reset", comment: "")
        warningLabel.text = NSLocalizedString("id_warning_there_is_already_a", comment: "")
        disputeButton.setTitle(NSLocalizedString("id_dispute_twofactor_reset", comment: ""), for: .normal)
        emailTextField.attributedPlaceholder = NSAttributedString(string: "email@domain.com",
                                                                  attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        hideKeyboardWhenTappedAround()
        errorLabel = UIErrorLabel(self.view)
    }

    @IBAction func disputeButtonClicked(_ sender: Any) {
        if self.isAnimating {
            return
        }
        errorLabel.isHidden = true
        if let email = emailTextField.text {
            self.startAnimating(CGSize(width: 30, height: 30),
                                type: NVActivityIndicatorType.ballRotateChase)
            DispatchQueue.global(qos: .background).async {
                wrap {
                    try getSession().resetTwoFactor(email: email, isDispute: true)
                }.done { (result: TwoFactorCall) in
                    try TwoFactorCallHelper(result, delegate: self).resolve()
                }.catch { error in
                    DispatchQueue.main.async {
                        self.onError(nil, text: error.localizedDescription)
                    }
                }
            }
        }
    }

    func onResolve(_ sender: TwoFactorCallHelper?) {
        let alert = TwoFactorCallHelper.CodePopup(sender!)
        self.present(alert, animated: true, completion: nil)
    }

    func onRequest(_ sender: TwoFactorCallHelper?) {
        let alert = TwoFactorCallHelper.MethodPopup(sender!)
        self.present(alert, animated: true, completion: nil)
    }

    func onDone(_ sender: TwoFactorCallHelper?) {
        self.stopAnimating()
        //self.navigationController?.popViewController(animated: true)
        getAppDelegate().logout()
    }

    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        self.stopAnimating()
        errorLabel.isHidden = false
        errorLabel.text = NSLocalizedString(text, comment: "")
    }
}
