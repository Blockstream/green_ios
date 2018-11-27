import Foundation
import UIKit
import NVActivityIndicatorView

class SetPhoneViewController: KeyboardViewController, NVActivityIndicatorViewable, TwoFactorCallDelegate {

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
        if self.isAnimating {
            return;
        }
        errorLabel.isHidden = true
        self.startAnimating(CGSize(width: 30, height: 30),
                            type: NVActivityIndicatorType.ballRotateChase)
        let dict = ["enabled": true, "confirmed": true, "data": self.textField.text!] as [String : Any]
        DispatchQueue.global(qos: .background).async {
            wrap {
                if (self.sms == true) {
                    return try getSession().changeSettingsTwoFactor(method: "sms", details: dict)
                } else {
                    return try getSession().changeSettingsTwoFactor(method: "phone", details: dict)
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
        self.navigationController?.popViewController(animated: true)
    }
    
    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        self.stopAnimating()
        errorLabel.isHidden = false
        errorLabel.text = NSLocalizedString(text, comment: "")
    }
}
