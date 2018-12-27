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
    var isFiat: Bool = true
    var errorLabel: UIErrorLabel!
    var limits: TwoFactorConfigLimits!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_twofactor_threshold", comment: "")
        setLimitButton.setTitle(NSLocalizedString("id_set_twofactor_threshold", comment: ""), for: .normal)
        limitTextField.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                                  attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        errorLabel = UIErrorLabel(self.view)
        refresh()
    }

    func refresh() {
        guard let dataTwoFactorConfig = try? getSession().getTwoFactorConfig() else { return }
        guard let twoFactorConfig = try? JSONDecoder().decode(TwoFactorConfig.self, from: JSONSerialization.data(withJSONObject: dataTwoFactorConfig!, options: [])) else { return }
        guard let settings = getGAService().getSettings() else { return }
        limits = twoFactorConfig.limits
        isFiat = limits.isFiat
        let amount: String
        let subtitle: String
        if isFiat == true {
            amount = limits.fiat
            subtitle = String(format: "%@ %@", amount, settings.getCurrency())
        } else {
            let denomination: String = settings.denomination.rawValue
            amount = limits.get(TwoFactorConfigLimits.CodingKeys(rawValue: denomination.lowercased())!)!
            subtitle = String(format: "%@ %@", amount, denomination)
        }
        limitTextField.text = amount
        descriptionLabel.text = String(format: NSLocalizedString("id_your_transaction_threshold_is_s", comment: ""), subtitle)
        setFiatButton()
    }

    @IBAction func setLimitClicked(_ sender: Any) {
        guard let amount = Double(limitTextField.text!) else { return }
        guard let settings = getGAService().getSettings() else { return }
        let details: [String:Any]
        if isFiat {
            details = ["is_fiat": isFiat, "fiat": String(amount)]
        } else {
            let denomination: String = settings.denomination.rawValue.lowercased()
            details = ["is_fiat": isFiat, denomination: String(amount)]
        }
        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            self.errorLabel.isHidden = true
            self.startAnimating()
            return Guarantee()
        }.compactMap(on: bgq) {
            try getSession().setTwoFactorLimit(details: details)
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
                case .failure(let localizedDescription), .cancel(let localizedDescription):
                    self.errorLabel.text = localizedDescription
                }
            } else {
                self.errorLabel.text = error.localizedDescription
            }
        }
    }

    func setFiatButton() {
        guard let settings = getGAService().getSettings() else { return }
        if isFiat {
            fiatButton.setTitle(settings.getCurrency(), for: UIControlState.normal)
            fiatButton.backgroundColor = UIColor.clear
            fiatButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        } else {
            fiatButton.setTitle(settings.denomination.rawValue, for: UIControlState.normal)
            fiatButton.backgroundColor = UIColor.customMatrixGreen()
            fiatButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        }
    }

    @IBAction func fiatButtonClicked(_ sender: Any) {
        isFiat = !isFiat
        setFiatButton()
    }
}
