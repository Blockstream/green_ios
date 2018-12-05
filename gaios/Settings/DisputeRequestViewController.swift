import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class DisputeRequestViewController : KeyboardViewController, NVActivityIndicatorViewable {

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
        errorLabel = UIErrorLabel(self.view)
    }

    @IBAction func disputeButtonClicked(_ sender: Any) {
        guard let email = emailTextField.text else { return }
        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            self.errorLabel.isHidden = true
            startAnimating(type: NVActivityIndicatorType.ballRotateChase)
            return Guarantee()
        }.then(on: bgq) {
            return Guarantee().compactMap(on: bgq) {
                try getSession().resetTwoFactor(email: email, isDispute: true)
            }
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { _ in
            getAppDelegate().logout()
        }.catch { error in
            self.errorLabel.isHidden = false
            if let twofaError = error as? TwoFactorCallError {
                switch twofaError {
                case .failure(let localizedDescription):
                    self.errorLabel.text = localizedDescription
                }
            } else {
                self.errorLabel.text = error.localizedDescription
            }
        }
    }
}
