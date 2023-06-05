import Foundation
import UIKit
import gdk

protocol AmountEditCellDelegate {
    func sendAll(enabled: Bool)
    func amountDidChange(text: String, isFiat: Bool)
    func onFocus()
}

struct AmountEditCellModel {
    let text: String?
    let error: String?
    let balance: Int64?
    let assetId: String
    let editable: Bool
    var sendAll: Bool = false
    var isFiat: Bool = false
    var isLightning: Bool = false

    var balanceText: String? {
        Balance.fromSatoshi(balance ?? 0, assetId: assetId)?.toText()
    }
    var balanceFiat: String? {
        Balance.fromSatoshi(balance ?? 0, assetId: assetId)?.toFiatText()
    }
    var satoshi: Int64? {
        if let text = text, !text.isEmpty {
            return Balance.from(text, assetId: assetId)?.satoshi
        }
        return nil
    }
    var ticker: String {
        Balance.fromSatoshi(0, assetId: assetId)?.toValue().1 ?? ""
    }
    
    var currency: String {
        Balance.fromSatoshi(0, assetId: assetId)?.toFiat().1 ?? ""
    }
}

class AmountEditCell: UITableViewCell {
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var denominationLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var pasteButton: UIButton!
    @IBOutlet weak var convertButton: UIButton!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var sendallButton: UIButton!

    private var cellModel: AmountEditCellModel?
    private var delegate: AmountEditCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        setStyle()
        setContent()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func prepareForReuse() {
    }

    func setContent() {
        errorLabel.text = ""
        sendallButton.setTitle("id_send_all_funds".localized, for: .normal)
        balanceLabel.text = ""
        denominationLabel.text = ""
        amountTextField.addDoneButtonToKeyboard(myAction: #selector(self.amountTextField.resignFirstResponder))
    }

    func setStyle() {
        bg.cornerRadius = 5.0
    }

    @IBAction func textEditChange(_ sender: Any) {
        triggerTextChange()
    }

    @IBAction func sendallTap(_ sender: Any) {
        let newState = !(cellModel?.sendAll ?? false)
        cellModel?.sendAll = newState
        sendAll(enabled: newState)
        delegate?.sendAll(enabled: newState)
    }

    @IBAction func convertTap(_ sender: Any) {
        let newState = !(cellModel?.isFiat ?? false)
        cellModel?.isFiat = newState
        balance(isFiat: newState)
        ticker(isFiat: newState)
        if newState {
            amountTextField.text = Balance.fromDenomination(amountTextField.text ?? "", assetId: cellModel?.assetId ?? AssetInfo.btcId)?.toFiat().0
        } else {
            amountTextField.text = Balance.fromFiat(amountTextField.text ?? "")?.toDenom().0
        }
        triggerTextChange()
    }

    @IBAction func pasteTap(_ sender: Any) {
        if let text = UIPasteboard.general.string {
            amountTextField.text = text
            triggerTextChange()
        }
    }

    @IBAction func cancelTap(_ sender: Any) {
        amountTextField.text = ""
        triggerTextChange()
    }

    func configure(cellModel: AmountEditCellModel, delegate: AmountEditCellDelegate) {
        self.delegate = delegate
        self.cellModel = cellModel
        errorLabel.text = cellModel.error?.localized ?? ""
        amountTextField.delegate = self
        //amountTextField.text = cellModel.text
        amountTextField.isEnabled = cellModel.editable
        amountTextField.isUserInteractionEnabled = cellModel.editable
        convertButton.isHidden = !AssetInfo.baseIds.contains(cellModel.assetId)
        pasteButton.isEnabled = cellModel.editable
        cancelButton.isEnabled = cellModel.editable
        sendallButton.isEnabled = cellModel.editable
        cancelButton.isHidden = (amountTextField.text?.isEmpty ?? false)
        pasteButton.isHidden = !(amountTextField.text?.isEmpty ?? false)
        amountTextField.addDoneButtonToKeyboard(myAction: #selector(self.amountTextField.resignFirstResponder))
        sendAll(enabled: cellModel.sendAll)
        balance(isFiat: cellModel.isFiat)
        ticker(isFiat: cellModel.isFiat)
        sendallButton.isHidden = cellModel.isLightning
    }

    func balance(isFiat: Bool) {
        balanceLabel.text = isFiat ? cellModel?.balanceFiat : cellModel?.balanceText
    }

    func ticker(isFiat: Bool) {
        denominationLabel.text = isFiat ? cellModel?.currency : cellModel?.ticker
    }

    func sendAll(enabled: Bool) {
        amountTextField.isUserInteractionEnabled = !enabled
        amountTextField.alpha = !enabled ? 1.0 : 0.6
        if enabled {
            sendallButton.setStyle(.primary)
            amountTextField.text = ""
        } else {
            sendallButton.setStyle(.outlinedGray)
            sendallButton.isEnabled = true
        }
    }

    @IBAction func amountDidChange(_ sender: Any) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0.5)
    }

    @objc func triggerTextChange() {
        if let text = amountTextField.text {
            delegate?.amountDidChange(text: text, isFiat: cellModel?.isFiat ?? false)
            cancelButton.isHidden = !(text.count > 0)
            pasteButton.isHidden = text.count > 0
        }
    }
}

extension AmountEditCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        endEditing(true)
        return false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == amountTextField {
            delegate?.onFocus()
        }
    }
}