import UIKit

enum LTWithdrawAmount {
    case insufficient
    case minInvalid
    case maxInvalid
    case valid
    case empty
}

class LTWithdrawAmountCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnSwitch: UIButton!
    @IBOutlet weak var btnPaste: UIButton!

    @IBOutlet weak var lblError: UILabel!
    @IBOutlet weak var lblLimits: UILabel!

    class var identifier: String { return String(describing: self) }

    var minAmount: UInt64 = 1
    var maxAmount: UInt64 = 0
    var amount: UInt64? {
        return UInt64(textField.text ?? "")
    }
    var onChange: ((UInt64?) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        btnSwitch.isHidden = true
        lblLimits.setStyle(.txtCard)
        btnPaste.isHidden = true
        textField.addDoneButtonToKeyboard(myAction: #selector(self.textField.resignFirstResponder))
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(maxAmount: UInt64,
                   onChange: ((UInt64?) -> Void)?) {
        self.maxAmount = maxAmount
        lblAsset.text = "sats"
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        self.onChange = onChange
        reload()
    }

    func responderOn() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
            self.textField.becomeFirstResponder()
        }
    }

    func reload() {
        lblError.isHidden = false
        lblLimits.isHidden = false
        lblLimits.text = String(format: "id_withdraw_limits_s__s".localized, "\(minAmount)", "\(maxAmount)")

        switch amountValidate() {
        case .insufficient:
            lblError.text = "id_insufficient_funds".localized
            lblLimits.isHidden = true
        case .minInvalid:
            lblError.text = String(format: "id_amount_must_be_at_least_s".localized, "\(minAmount)")
        case .maxInvalid:
            lblError.text = String(format: "id_amount_must_be_at_most_s".localized, "\(maxAmount)")
        case .valid:
            lblError.isHidden = true
        case .empty:
            lblError.isHidden = true
        }

        switch amountValidate() {
        case .valid:
            onChange?(amount)
        default:
            onChange?(nil)
        }
    }

    func amountValidate() -> LTWithdrawAmount {
        if maxAmount == 0 {return .insufficient}
        if textField.text == "" {
            return .empty
        }
        guard let amount = amount else { return .minInvalid }
        if amount > maxAmount { return .maxInvalid }
        if amount < minAmount { return .minInvalid }
        return .valid
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0.5)
    }

    @objc func triggerTextChange() {
        reload()
    }

    @IBAction func btnInputDenomination(_ sender: Any) {
    }
}
