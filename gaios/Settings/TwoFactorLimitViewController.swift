import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class TwoFactorLimitViewController: KeyboardViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var limitTextField: UITextField!
    @IBOutlet weak var setLimitButton: UIButton!
    @IBOutlet weak var fiatButton: UIButton!
    @IBOutlet weak var limitButtonConstraint: NSLayoutConstraint!
    var fiat: Bool = true
    @IBOutlet weak var descriptionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setButton()
        title = NSLocalizedString("id_twofactor_threshold", comment: "")
        setLimitButton.setTitle(NSLocalizedString("id_set_twofactor_threshold", comment: ""), for: .normal)
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
            if isFiat {
                amount = limits["fiat"] as! String
            } else {
                amount = limits[denomination] as! String
            }
            limitTextField.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                                      attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])

            if !amount.isEmpty {
                limitTextField.text = amount
                var localized = NSLocalizedString("id_your_transaction_threshold_is_s", comment: "")
                localized = String(format: localized, amount) + " "
                if isFiat {
                    localized = localized + denomination;
                } else {
                    let ccy = limits["fiat_currency"] as! String
                    localized = localized + ccy;
                }
                descriptionLabel.text = localized
            }
            fiat = isFiat
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
        guard let amount = Double(limitTextField.text!) else { return }
        var details = [String:Any]()
        if(fiat) {
            details["is_fiat"] = true
            details["fiat"] = String(amount)
        } else {
            details["is_fiat"] = false
            let denomination = getDenominationKey(SettingsStore.shared.getDenominationSettings())
            details[denomination] = limitTextField.text!
        }
        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            startAnimating(type: NVActivityIndicatorType.ballRotateChase)
            return Guarantee()
        }.then(on: bgq) {
            return Guarantee().compactMap(on: bgq) {
                try getSession().setTwoFactorLimit(details: details)
            }
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.done { _ in
            self.stopAnimating()
            SettingsStore.shared.setTwoFactorLimit()
            self.navigationController?.popViewController(animated: true)
        }.catch { error in
            self.stopAnimating()
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
}
