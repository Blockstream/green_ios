import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class TwoFactorLimitViewController: KeyboardViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var limitTextField: UITextField!
    @IBOutlet weak var setLimitButton: UIButton!
    @IBOutlet weak var fiatButton: UIButton!
    @IBOutlet weak var limitButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var convertedLabel: UILabel!
    fileprivate var isFiat = false
    fileprivate var limits: TwoFactorConfigLimits!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_twofactor_threshold", comment: "")
        setLimitButton.setTitle(NSLocalizedString("id_set_twofactor_threshold", comment: ""), for: .normal)
        limitTextField.becomeFirstResponder()
        limitTextField.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                                  attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        limitTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        guard let dataTwoFactorConfig = try? getSession().getTwoFactorConfig() else { return }
        guard let twoFactorConfig = try? JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig!, options: [])) else { return }
        guard let settings = getGAService().getSettings() else { return }
        limits = twoFactorConfig.limits
        isFiat = limits.isFiat
        let amount = isFiat ? limits.fiat : limits.get(TwoFactorConfigLimits.CodingKeys(rawValue: settings.denomination.rawValue)!)!
        let subtitle = isFiat ? String(format: "%@ %@", amount, settings.getCurrency()) : String(format: "%@ %@", amount, settings.denomination.toString())
        limitTextField.text = amount
        descriptionLabel.text = String(format: NSLocalizedString("id_your_transaction_threshold_is_s", comment: ""), subtitle)
        refresh()
    }

    override func keyboardWillShow(notification: NSNotification) {
        let userInfo = notification.userInfo! as NSDictionary
        let keyboardFrame = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        setLimitButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -keyboardFrame.cgRectValue.height).isActive = true
    }

    func refresh() {
        guard let settings = getGAService().getSettings() else { return }
        let satoshi = getSatoshi()
        if isFiat {
            fiatButton.setTitle(settings.getCurrency(), for: UIControlState.normal)
            fiatButton.backgroundColor = UIColor.clear
            fiatButton.setTitleColor(UIColor.white, for: UIControlState.normal)
            convertedLabel.text = "≈ " + String.toBtc(satoshi: satoshi)
        } else {
            fiatButton.setTitle(settings.denomination.toString(), for: UIControlState.normal)
            fiatButton.backgroundColor = UIColor.customMatrixGreen()
            fiatButton.setTitleColor(UIColor.white, for: UIControlState.normal)
            convertedLabel.text = "≈ " + String.toFiat(satoshi: satoshi)
        }
    }

    @IBAction func setLimitClicked(_ sender: Any) {
        guard let amountText = limitTextField.text else { return }
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) else { return }
        guard let settings = getGAService().getSettings() else { return }
        let details: [String:Any]
        if isFiat {
            details = ["is_fiat": isFiat, "fiat": String(amount)]
        } else {
            let denomination: String = settings.denomination.rawValue
            details = ["is_fiat": isFiat, denomination: String(amount)]
        }
        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            self.startAnimating()
            return Guarantee()
        }.compactMap(on: bgq) {
            try getSession().setTwoFactorLimit(details: details)
        }.then(on: bgq) { call in
            call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { _ in
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

    @IBAction func fiatButtonClicked(_ sender: Any) {
        isFiat = !isFiat
        refresh()
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        refresh()
    }

    func getSatoshi() -> UInt64 {
        let amount: String = limitTextField.text!
        if (amount.isEmpty || Double(amount) == nil) {
            return 0
        }
        if isFiat {
            return String.toSatoshi(fiat: amount)
        } else {
            return String.toSatoshi(amount: amount)
        }
    }}
