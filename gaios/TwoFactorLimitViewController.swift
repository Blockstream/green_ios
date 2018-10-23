import Foundation
import UIKit

class TwoFactorLimitViewController: UIViewController {

    @IBOutlet weak var limitTextField: UITextField!
    @IBOutlet weak var setLimitButton: UIButton!
    @IBOutlet weak var fiatButton: UIButton!
    @IBOutlet weak var limitButtonConstraint: NSLayoutConstraint!
    var fiat: Bool = true
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(TwoFactorLimitViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TwoFactorLimitViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        setButton()
        if(!AccountStore.shared.isTwoFactorEnabled()) {
            setLimitButton.isEnabled = false
            descriptionLabel.text = NSLocalizedString("pyou_need_to_enable_twofactor", comment: "")
        }
        titleLabel.text = NSLocalizedString("ptwofactor_treshold", comment: "")
        descriptionLabel.text = NSLocalizedString("pyou_dont_need_two_factor_code", comment: "")
        setLimitButton.setTitle(NSLocalizedString("pset_limit", comment: ""), for: .normal)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let position =  self.view.frame.height - keyboardSize.height - setLimitButton.frame.height
            var keyboardHeight = keyboardSize.height
            if #available(iOS 11.0, *) {
                let bottomInset = view.safeAreaInsets.bottom
                keyboardHeight -= bottomInset
            }
            limitButtonConstraint.constant = keyboardHeight
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            limitButtonConstraint.constant = 0
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        limitTextField.becomeFirstResponder()
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func setLimitClicked(_ sender: Any) {
        if let amount = Double(limitTextField.text!) {
            do {
                var details = [String:Any]()
                if(fiat) {
                    details["is_fiat"] = true
                    details["fiat"] = String(amount)
                } else {
                    details["is_fiat"] = false
                    details["satoshi"] = String(amount)
                }
                let factor = try getSession().setTwoFactorLimit(details: details)
                let status = try factor.getStatus()
                let statusString = status!["status"] as! String
                if (statusString == "request_code") {
                    let methods = status!["methods"] as! NSArray
                    if (methods.count == 1) {
                        let met = methods[0] as! String
                        let request = try factor.requestCode(method: met)
                        self.performSegue(withIdentifier: "verifyCode", sender: factor)
                    } else {
                        self.performSegue(withIdentifier: "selectTwoFactor", sender: factor)
                    }
                }
            } catch {
                print("couldnt set limit")
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
            nextController.hideButton = true
        }
        if let nextController = segue.destination as? TwoFactorSlectorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
        }
    }

    func setButton() {
        if(fiat) {
            fiatButton.setTitle(SettingsStore.shared.getCurrencyString(), for: UIControlState.normal)
            fiatButton.backgroundColor = UIColor.clear
            fiatButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        } else {
            fiatButton.setTitle(SettingsStore.shared.getDenominationSettings(), for: UIControlState.normal)
            fiatButton.backgroundColor = UIColor.customMatrixGreen()
            fiatButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        }
    }

    @IBAction func fiatButtonClicked(_ sender: Any) {
        if(fiat) {
            fiat = !fiat
            setButton()
        } else {
            fiat = !fiat
            setButton()
        }
    }
}
