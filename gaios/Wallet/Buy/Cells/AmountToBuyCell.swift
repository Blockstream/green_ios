import UIKit
import gdk

enum AmountToBuyCellState: Int {
    case valid
    case invalid
}

protocol AmountToBuyCellDelegate: AnyObject {
    func textFieldDidChange(_ satoshi: Int64?, isFiat: Bool)
    func textFieldEnabled()
    func onInputDenomination()
    func stateDidChange(_ state: AmountToBuyCellState)
}

class AmountToBuyCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var infoPanel: UIView!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnPaste: UIButton!
    @IBOutlet weak var btnSwitch: UIButton!
    @IBOutlet weak var btnEdit: UIButton!
    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var infoPanelTop: NSLayoutConstraint!
    
    weak var delegate: AmountToBuyCellDelegate?
    var model: AmountToBuyCellModel!
    var enabled: Bool = true

    static var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        bg.borderWidth = 1.0
        infoPanel.cornerRadius = 5.0
        lblAmount.setStyle(.txtCard)
        lblAsset.setStyle(.txtBigger)
        lblInfo.setStyle(.txt)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: AmountToBuyCellModel, delegate: AmountToBuyCellDelegate?) {
        self.delegate = delegate
        self.model = model
        textField.text = model.amount
        lblAsset.attributedText = model.denomUnderlineText
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        triggerTextChange()
        textField.addDoneButtonToKeyboard(myAction: #selector(self.textField.resignFirstResponder))
    }

    func reload() {
        textField.isEnabled = enabled
        btnEdit.isHidden = enabled
        btnCancel.isHidden = !enabled
        btnPaste.isHidden = !enabled
        btnCancel.isHidden = !(textField.text?.count ?? 0 > 0)
        btnPaste.isHidden = textField.text?.count ?? 0 > 0
        lblAmount.text = model.subamountText
        lblAsset.attributedText = model.denomUnderlineText
    }

    func getSatoshi(_ value: String) -> Int64? {
        if model.isFiat {
            let balance = Balance.fromFiat(value)
            return balance?.satoshi
        } else {
            let balance = Balance.fromDenomination(value, assetId: AssetInfo.btcId, denomination: model.inputDenomination)
            return balance?.satoshi
        }
    }

    @objc func triggerTextChange() {
        if let value = textField.text {
            let satoshi = self.getSatoshi(value)
            self.model.satoshi = satoshi
            self.reload()
            self.reloadState()
            self.delegate?.textFieldDidChange(satoshi, isFiat: self.model.isFiat)
            self.delegate?.stateDidChange(self.model.state)
        }
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0)
    }

    @IBAction func onEdit(_ sender: Any) {
        enabled = true
        reload()
        textField.becomeFirstResponder()
        delegate?.textFieldEnabled()
    }

    @IBAction func onSwitch(_ sender: Any) {
        delegate?.onInputDenomination()
    }

    @IBAction func btnPaste(_ sender: Any) {
        if let text = UIPasteboard.general.string {
            textField.text = text
            textFieldDidChange(textField)
        }
    }

    @IBAction func btnCancel(_ sender: Any) {
        textField.text = ""
        textFieldDidChange(textField)
    }

    func reloadState() {
        if !model.showMessage {
            bg.borderColor = UIColor.clear
            infoPanel.backgroundColor = UIColor.clear
        } else if model.state == .valid {
            bg.borderColor = UIColor.gGreenMatrix()
            infoPanel.backgroundColor = UIColor.gGreenMatrix().withAlphaComponent(1.0)
        } else {
            bg.borderColor = UIColor.gRedFluo()
            infoPanel.backgroundColor = UIColor.gRedWarn()
        }
        lblInfo.text = model.message
        lblInfo.isHidden = !model.showMessage
        lblAmount.isHidden = model.hideSubamount
        infoPanelTop.constant = model.showMessage ? -1 : -11
    }

    @IBAction func btnInputDenomination(_ sender: Any) {
        delegate?.onInputDenomination()
    }
}
