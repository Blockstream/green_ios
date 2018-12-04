import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class RequestTwoFactorReset : KeyboardViewController, NVActivityIndicatorViewable {

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
            warningLabel.text = NSLocalizedString("id_twofactor_reset_in_progress", comment: "")
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
        var email: String = ""
        if !self.isReset {
            email = emailTextField.text!
        }
        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            self.errorLabel.isHidden = true
            startAnimating(type: NVActivityIndicatorType.ballRotateChase)
            return Guarantee()
        }.then(on: bgq) {
            return (self.isReset == true) ?
                Guarantee().compactMap(on: bgq) {
                    return try getSession().cancelTwoFactorReset()
                } :
                Guarantee().compactMap(on: bgq) {
                    return try getSession().resetTwoFactor(email: email, isDispute: false)
                }
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.done { _ in
            self.stopAnimating()
            getAppDelegate().logout()
        }.catch { error in
            self.stopAnimating()
            self.errorLabel.isHidden = false
            self.errorLabel.text = NSLocalizedString(error.localizedDescription, comment: "")
            self.updateUI()
        }
    }
}
