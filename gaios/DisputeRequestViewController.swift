import Foundation
import UIKit
import NVActivityIndicatorView

class DisputeRequestViewController : UIViewController, NVActivityIndicatorViewable, TwoFactorCallDelegate {

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
        if self.isAnimating {
            return
        }
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
        print(text)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        if !self.isAnimating {
            self.navigationController?.popViewController(animated: true)
        }
    }
}
