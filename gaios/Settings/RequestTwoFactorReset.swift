import Foundation
import UIKit
import NVActivityIndicatorView

class RequestTwoFactorReset : UIViewController, NVActivityIndicatorViewable, TwoFactorCallDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!
    @IBOutlet weak var disputeButton: UIButton!
    var isReset = false
    var errorLabel: UIErrorLabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emailTextField.attributedPlaceholder = NSAttributedString(string: "email@domain.com",
                                                                  attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        hideKeyboardWhenTappedAround()
        title = NSLocalizedString("id_request_twofactor_reset", comment: "")
        emailLabel.text = NSLocalizedString("id_enter_new_email", comment: "")
        warningLabel.text = NSLocalizedString("id_warning_resetting_twofactor", comment: "")
        requestButton.setTitle(NSLocalizedString("id_request", comment: ""), for: .normal)
        NotificationCenter.default.addObserver(self, selector: #selector(self.resetChanged(_:)), name: NSNotification.Name(rawValue: "twoFactorReset"), object: nil)
        errorLabel = UIErrorLabel(self.view)
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

    @IBAction func disputeButtonClicekd(_ sender: Any) {
        if !self.isAnimating {
            self.performSegue(withIdentifier: "disputeRequest", sender: nil)
        }
    }

    @IBAction func requestClicked(_ sender: Any) {
        if self.isAnimating {
            return
        }
        errorLabel.isHidden = true
        self.startAnimating(CGSize(width: 30, height: 30),
                            type: NVActivityIndicatorType.ballRotateChase)
        DispatchQueue.global(qos: .background).async {
            wrap {
                if self.isReset {
                    return try getSession().cancelTwoFactorReset()
                } else if let email = self.emailTextField.text {
                    return try getSession().resetTwoFactor(email: email, isDispute: false)
                } else {
                    throw GaError.GenericError
                }
            }.done { (result: TwoFactorCall) in
                try TwoFactorCallHelper(result, delegate: self).resolve()
            }.catch { error in
                DispatchQueue.main.async {
                    self.onError(nil, text: error.localizedDescription)
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
        getAppDelegate().logout()
    }

    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        self.stopAnimating()
        errorLabel.isHidden = false
        errorLabel.text = NSLocalizedString(text, comment: "")
        updateUI()
    }
}
