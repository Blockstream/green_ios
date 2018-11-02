import Foundation
import UIKit

class SetPhoneViewController: UIViewController, TwoFactorCallDelegate {

    @IBOutlet weak var textField: SearchTextField!
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!
    @IBOutlet weak var getCodeButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    var sms = false
    var phoneCall = false
    var onboarding = true
    var twoFactorController: UIViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        hideKeyboardWhenTappedAround()
        NotificationCenter.default.addObserver(self, selector: #selector(SetEmailViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SetEmailViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        textField.attributedPlaceholder = NSAttributedString(string: "+1 123456789",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        getCodeButton.setTitle(NSLocalizedString("id_get_code", comment: ""), for: .normal)
        titleLabel.text = NSLocalizedString("id_enter_phone_number", comment: "")
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
        var twoFactor: TwoFactorCall? = nil
        DispatchQueue.global(qos: .background).async {
            wrap {
                if (self.sms == true) {
                     return AccountStore.shared.enableSMSTwoFactor(phoneNumber: self.textField.text!)
                } else {
                     return AccountStore.shared.enablePhoneCallTwoFactor(phoneNumber: self.textField.text!)
                }
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

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0{
                var keyboardHeight = keyboardSize.height
                if #available(iOS 11.0, *) {
                    let bottomInset = view.safeAreaInsets.bottom
                    keyboardHeight -= bottomInset
                }
                buttonConstraint.constant += keyboardHeight
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y != 0{
                var keyboardHeight = keyboardSize.height
                if #available(iOS 11.0, *) {
                    let bottomInset = view.safeAreaInsets.bottom
                    keyboardHeight -= bottomInset
                }
                buttonConstraint.constant -= keyboardHeight
            }
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    func onResolve(_ sender: TwoFactorCallHelper) {
        let alert = TwoFactorCallHelper.CodePopup(sender)
        presetTwoFactorController(c: alert)
    }

    func onRequest(_ sender: TwoFactorCallHelper) {
        let selector = TwoFactorCallHelper.MethodPopup(sender)
        presetTwoFactorController(c: selector)
    }

    func presetTwoFactorController(c: UIViewController) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: {
                self.twoFactorController = c
                self.present(c, animated: true, completion: nil)
            })
        } else {
            twoFactorController = c
            self.present(c, animated: true, completion: nil)
        }
    }

    func onDone(_ sender: TwoFactorCallHelper) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: nil)
        }
        if(onboarding) {
            self.performSegue(withIdentifier: "mainMenu", sender: nil)
        } else {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }

    func onError(_ sender: TwoFactorCallHelper, text: String) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: nil)
        }
    }

}
