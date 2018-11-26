import Foundation
import UIKit
import NVActivityIndicatorView

class TwoFactorLimitViewController: UIViewController, NVActivityIndicatorViewable, TwoFactorCallDelegate {

    @IBOutlet weak var limitTextField: UITextField!
    @IBOutlet weak var setLimitButton: UIButton!
    @IBOutlet weak var fiatButton: UIButton!
    @IBOutlet weak var limitButtonConstraint: NSLayoutConstraint!
    var fiat: Bool = true
    @IBOutlet weak var descriptionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(TwoFactorLimitViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TwoFactorLimitViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        setButton()
        if(!AccountStore.shared.isTwoFactorEnabled()) {
            setLimitButton.isEnabled = false
            descriptionLabel.text = NSLocalizedString("id_you_need_to_enable_twofactor", comment: "")
        }
        title = NSLocalizedString("id_twofactor_threshold", comment: "")
        descriptionLabel.text = NSLocalizedString("id_you_dont_need_twofactor", comment: "")
        setLimitButton.setTitle(NSLocalizedString("id_set_limit", comment: ""), for: .normal)
        refesh()
        setButton()
        SettingsStore.shared.setTwoFactorLimit()
    }

    func refesh() {
        if let config = try! getSession().getTwoFactorConfig() {
            let limits = config["limits"] as! [String: Any]
            let isFiat = limits["is_fiat"] as! Bool
            let denomination = getDenominationKey(SettingsStore.shared.getDenominationSettings())
            var amount = ""
            if !isFiat {
                amount = limits[denomination] as! String
            } else {
                amount = limits["fiat"] as! String
            }
            limitTextField.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                                      attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
            if !amount.isEmpty {
                limitTextField.text = amount
            }
            fiat = isFiat
        }
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
        if !self.isAnimating {
            self.navigationController?.popViewController(animated: true)
        }
    }

    @IBAction func setLimitClicked(_ sender: Any) {
        if self.isAnimating {
            return
        }
        let amount = limitTextField.text!
        if Double(amount) != nil {
            do {
                var details = [String:Any]()
                if(fiat) {
                    details["is_fiat"] = true
                    details["fiat"] = String(amount)
                } else {
                    details["is_fiat"] = false
                    let denomination = getDenominationKey(SettingsStore.shared.getDenominationSettings())
                    details[denomination] = limitTextField.text!
                }
                self.startAnimating(CGSize(width: 30, height: 30),
                                    type: NVActivityIndicatorType.ballRotateChase)
                DispatchQueue.global(qos: .background).async {
                    wrap {
                        try getSession().setTwoFactorLimit(details: details)
                    }.done { (result: TwoFactorCall) in
                        try TwoFactorCallHelper(result, delegate: self).resolve()
                    }.catch { error in
                        DispatchQueue.main.async {
                            self.onError(nil, text: error.localizedDescription)
                        }
                    }
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
        SettingsStore.shared.setTwoFactorLimit()
        self.navigationController?.popViewController(animated: true)
    }

    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        self.stopAnimating()
        print(text)
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
}
