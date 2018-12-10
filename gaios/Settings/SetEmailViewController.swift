import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class SetEmailViewController: KeyboardViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var getCodeButton: UIButton!
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!
    var errorLabel: UIErrorLabel!

    override func viewDidLoad() {
        super.viewDidLoad()
       textField.attributedPlaceholder = NSAttributedString(string: "email@domainm.com",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        getCodeButton.setTitle(NSLocalizedString("id_get_code", comment: ""), for: .normal)
        title = NSLocalizedString("id_enter_your_email_address", comment: "")
        errorLabel = UIErrorLabel(self.view)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        getCodeButton.backgroundColor = UIColor.customTitaniumLight()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        getCodeButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func getCodeClicked(_ sender: Any) {
        let bgq = DispatchQueue.global(qos: .background)
        let config = TwoFactorConfigItem(enabled: true, confirmed: true, data: self.textField.text!)
        firstly {
            self.errorLabel.isHidden = true
            startAnimating(type: NVActivityIndicatorType.ballRotateChase)
            return Guarantee()
        }.compactMap(on: bgq) {
            try getGAService().getSession().changeSettingsTwoFactor(method: TwoFactorType.email.rawValue, details: try JSONSerialization.jsonObject(with: JSONEncoder().encode(config), options: .allowFragments) as! [String : Any])
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { _ in
            self.navigationController?.popViewController(animated: true)
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
