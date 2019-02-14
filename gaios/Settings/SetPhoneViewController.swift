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

    override func viewDidLoad() {
        super.viewDidLoad()
        textField.becomeFirstResponder()
        textField.attributedPlaceholder = NSAttributedString(string: "+1 123456789",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        getCodeButton.setTitle(NSLocalizedString("id_get_code", comment: ""), for: .normal)
        title = NSLocalizedString("id_enter_phone_number", comment: "")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        getCodeButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    override func keyboardWillShow(notification: NSNotification) {
        let userInfo = notification.userInfo! as NSDictionary
        let keyboardFrame = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        getCodeButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -keyboardFrame.cgRectValue.height).isActive = true
    }

    @IBAction func getCodeClicked(_ sender: Any) {
        let bgq = DispatchQueue.global(qos: .background)
        let method = self.sms == true ? TwoFactorType.sms : TwoFactorType.phone
        let config = TwoFactorConfigItem(enabled: true, confirmed: true, data: self.textField.text!)
        firstly {
            self.startAnimating()
            return Guarantee()
        }.compactMap(on: bgq) {
            try getGAService().getSession().changeSettingsTwoFactor(method: method.rawValue, details: try JSONSerialization.jsonObject(with: JSONEncoder().encode(config), options: .allowFragments) as! [String : Any])
        }.then(on: bgq) { call in
            call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { _ in
            getGAService().reloadTwoFactor()
            self.navigationController?.popViewController(animated: true)
        }.catch { error in
            if let twofaError = error as? TwoFactorCallError {
                switch twofaError {
                case .failure(let localizedDescription), .cancel(let localizedDescription):
                    Toast.show(localizedDescription)
                }
            } else {
                Toast.show(error.localizedDescription)
            }
        }
    }
}
