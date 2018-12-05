import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class SetPhoneViewController: KeyboardViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var textField: SearchTextField!
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!
    @IBOutlet weak var getCodeButton: UIButton!
    var sms = false
    var phoneCall = false
    var onboarding = true
    var errorLabel: UIErrorLabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        textField.attributedPlaceholder = NSAttributedString(string: "+1 123456789",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        getCodeButton.setTitle(NSLocalizedString("id_get_code", comment: ""), for: .normal)
        title = NSLocalizedString("id_enter_phone_number", comment: "")
        errorLabel = UIErrorLabel(self.view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        textField.becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        getCodeButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func getCodeClicked(_ sender: Any) {
        let bgq = DispatchQueue.global(qos: .background)
        let dict = ["enabled": true, "confirmed": true, "data": self.textField.text!] as [String : Any]
        let method = self.sms == true ? "sms" : "phone"
        firstly {
            self.errorLabel.isHidden = true
            startAnimating(type: NVActivityIndicatorType.ballRotateChase)
            return Guarantee()
        }.then(on: bgq) {
            return Guarantee().compactMap(on: bgq) {
                try getSession().changeSettingsTwoFactor(method: method, details: dict)
            }
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { _ in
            self.navigationController?.popViewController(animated: true)
        }.catch { error in
            self.errorLabel.isHidden = false
            self.errorLabel.text = NSLocalizedString(error.localizedDescription, comment: "")
        }
    }
}
