import Foundation
import UIKit
import NVActivityIndicatorView

class SetEmailViewController: UIViewController, NVActivityIndicatorViewable, TwoFactorCallDelegate {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var getCodeButton: UIButton!
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleLabel: UILabel!
    var onboarding = true

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(SetEmailViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SetEmailViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        textField.attributedPlaceholder = NSAttributedString(string: "email@domainm.com",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        getCodeButton.setTitle(NSLocalizedString("id_get_code", comment: ""), for: .normal)
        titleLabel.text = NSLocalizedString("id_enter_your_email_address", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getCodeButton.backgroundColor = UIColor.customTitaniumLight()
        textField.becomeFirstResponder()
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        getCodeButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func getCodeClicked(_ sender: Any) {
        DispatchQueue.global(qos: .background).async {
            wrap {
                 AccountStore.shared.enableEmailTwoFactor(email: self.textField.text!)
                }.done { (result: TwoFactorCall?) in
                    do {
                        let resultHelper = TwoFactorCallHelper(result!)
                        resultHelper.delegate = self
                        try resultHelper.resolve()
                    } catch {
                        self.stopAnimating()
                        print(error)
                    }
                } .catch { error in
                    self.stopAnimating()
                    print(error)
            }
        }
    }

    func failureMessage() {
        DispatchQueue.main.async {
            NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed")
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            self.stopAnimating()
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

    func onResolve(_ sender: TwoFactorCallHelper) {
        self.stopAnimating()
        let alert = TwoFactorCallHelper.CodePopup(sender)
        alert.onboarding = onboarding
        self.present(alert, animated: true, completion: nil)
    }

    func onRequest(_ sender: TwoFactorCallHelper) {
        self.stopAnimating()
        let selector = TwoFactorCallHelper.MethodPopup(sender)
        self.present(selector, animated: true, completion: nil)
    }

    func onDone(_ sender: TwoFactorCallHelper) {
        print("done")
    }

    func onError(_ sender: TwoFactorCallHelper, text: String) {
        failureMessage()
    }

}
