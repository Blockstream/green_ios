import Foundation
import UIKit

class TwoFactorLimitViewController: UIViewController, TwoFactorCallDelegate {

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
            descriptionLabel.text = NSLocalizedString("id_you_need_to_enable_twofactor", comment: "")
        }
        titleLabel.text = NSLocalizedString("id_twofactor_treshold", comment: "")
        descriptionLabel.text = NSLocalizedString("id_you_dont_need_twofactor", comment: "")
        setLimitButton.setTitle(NSLocalizedString("id_set_limit", comment: ""), for: .normal)
        let limits = AccountStore.shared.getTwoFactorLimit()
        fiat = limits.isFiat
        if (limits.amount == 0) {
            limitTextField.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                                       attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        } else if (!fiat){
            let denomination = SettingsStore.shared.getDenominationSettings()
            var amount_denominated: Double = 0
            if(denomination == DenominationType.BTC) {
                amount_denominated = limits.amount
            } else if (denomination == DenominationType.MilliBTC) {
                amount_denominated = limits.amount * 1000
            } else if (denomination == DenominationType.MicroBTC){
                amount_denominated = limits.amount * 1000000
            }
            limitTextField.text = String(amount_denominated)
        } else if (fiat) {
            limitTextField.text = String(limits.amount)
        }
        setButton()
        SettingsStore.shared.setTwoFactorLimit()
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
            var details = [String:Any]()
            if(fiat) {
                details["is_fiat"] = true
                details["fiat"] = String(amount)
            } else {
                details["is_fiat"] = false
                let denomination = SettingsStore.shared.getDenominationSettings()
                var amount_denominated: Double = 0
                if(denomination == DenominationType.BTC) {
                    amount_denominated = amount * 100000000
                } else if (denomination == DenominationType.MilliBTC) {
                    amount_denominated = amount * 100000
                } else if (denomination == DenominationType.MicroBTC){
                    amount_denominated = amount * 100
                }
                details["satoshi"] = amount_denominated
            }
            DispatchQueue.global(qos: .background).async {
                wrap {
                    try getSession().setTwoFactorLimit(details: details)
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
    }

    func setButton() {
        if(fiat) {
            fiatButton.setTitle(SettingsStore.shared.getCurrencyString(), for: UIControlState.normal)
            fiatButton.backgroundColor = UIColor.clear
            fiatButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        } else {
            fiatButton.setTitle(SettingsStore.shared.getDenominationSettings().rawValue, for: UIControlState.normal)
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

    func onResolve(_ sender: TwoFactorCallHelper) {
        let alert = TwoFactorCallHelper.CodePopup(sender)
        alert.onboarding = false
        self.present(alert, animated: true, completion: nil)
    }

    func onRequest(_ sender: TwoFactorCallHelper) {
        let selector = TwoFactorCallHelper.MethodPopup(sender)
        self.present(selector, animated: true, completion: nil)
    }

    func onDone(_ sender: TwoFactorCallHelper) {
        self.navigationController?.popViewController(animated: true)
    }

    func onError(_ sender: TwoFactorCallHelper, text: String) {
    }
}
