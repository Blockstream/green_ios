import UIKit
import gdk

enum AmountCellState: Int {
    case valid
    //case validFunding
    case aboveInboundLiquidity
    case tooHigh
    case tooLow
    case disabled
    case invalidAmount
    case disconnected
    case invalidBuy
}

protocol AmountCellDelegate: AnyObject {
    func textFieldDidChange(_ satoshi: Int64?, isFiat: Bool)
    func textFieldEnabled()
    func onFeeInfo()
    func onInputDenomination()
    func stateDidChange(_ state: AmountCellState)
}

class AmountCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var infoPanel: UIView!

    @IBOutlet weak var lblMoreInfo: UILabel!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnPaste: UIButton!
    @IBOutlet weak var btnSwitch: UIButton!
    @IBOutlet weak var btnEdit: UIButton!
    @IBOutlet weak var btnFeeInfo: UIButton!
    @IBOutlet weak var lblToReceiveTitle: UILabel!
    @IBOutlet weak var lblToReceiveHint: UILabel!
    @IBOutlet weak var bottomStackPad: NSLayoutConstraint!

    var state: AmountCellState = .valid
    weak var delegate: AmountCellDelegate?
    var model: AmountCellModel!
    var enabled: Bool = true

    static var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        bg.borderWidth = 1.0
        infoPanel.cornerRadius = 5.0
        lblAmount.setStyle(.txtCard)
        lblAsset.setStyle(.txtBigger)
        [lblToReceiveTitle, lblToReceiveHint].forEach {
            $0?.setStyle(.sectionTitle)
            $0?.text = ""
        }
        lblToReceiveTitle.text = "id_amount_to_receive".localized
        lblMoreInfo.text = "id_for_more_information".localized
        btnFeeInfo.setStyle(.underline(txt: "id_read_more".localized, color: .white))
        lblToReceiveHint.text = ""
        lblInfo.text = ""
        lblAmount.text = ""
        lblMoreInfo.isHidden = true
        btnFeeInfo.isHidden = true
        lblToReceiveTitle.isHidden = true
        lblToReceiveHint.isHidden = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: AmountCellModel, delegate: AmountCellDelegate?, enabled: Bool) {
        self.delegate = delegate
        self.model = model
        self.enabled = enabled
        textField.text = model.amountText
        lblAsset.attributedText = model.denomUnderlineText
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        if !enabled {
            state = .disabled
        }
        triggerTextChange()
    }

    func reload() {
        textField.isEnabled = enabled
        btnEdit.isHidden = enabled
        btnCancel.isHidden = !enabled
        btnPaste.isHidden = !enabled
        btnCancel.isHidden = !(textField.text?.count ?? 0 > 0)
        btnPaste.isHidden = textField.text?.count ?? 0 > 0
        let balance = "\(model?.maxLimitAmount ?? "") \(model?.denomText ?? "")"
        lblAmount.text = String(format: "id_max_limit_s".localized, balance)
        lblAsset.attributedText = model?.denomUnderlineText
        if model.scope == .buyBtc {
            lblInfo.isHidden = !model.showMessage
            lblToReceiveHint.isHidden = model.hideSubamount
            lblAmount.isHidden = true
            bottomStackPad.constant = model.showMessage ? 10 : -24
        }
    }

    func toReceiveAmount(show: Bool) {
        [lblToReceiveTitle, lblToReceiveHint].forEach {
            $0?.isHidden = !show
        }
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
            Task.detached { [weak self] in
                let satoshi = await self?.getSatoshi(value)
                let fee = await self?.model.buildOpenChannelFee(satoshi ?? 0)
                await MainActor.run { [weak self] in
                    self?.model.satoshi = satoshi
                    self?.model.setOpenChannelFee(fee ?? 0)
                    self?.updateState()
                    self?.reload()
                    if let self = self {
                        self.delegate?.textFieldDidChange(satoshi, isFiat: self.model.isFiat)
                        self.delegate?.stateDidChange(self.model.state)
                    }
                }
            }
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

    func errorState(text: String) {
        bg.borderColor = UIColor.gRedWarn()
        infoPanel.backgroundColor = UIColor.gRedWarn()
        btnFeeInfo.setStyle(.underline(txt: "id_read_more".localized, color: .white))
        lblInfo.text = text
        lblInfo.isHidden = false
        btnFeeInfo.isHidden = false
        lblMoreInfo.isHidden = false
        lblAmount.isHidden = true
        toReceiveAmount(show: false)
    }

    func disableState() {
        bg.borderColor = UIColor.gBlackBg()
        infoPanel.backgroundColor = UIColor.clear
        // lblInfo.isHidden = true
        lblInfo.text = " "
        btnFeeInfo.isHidden = true
        lblMoreInfo.isHidden = true
        lblAmount.isHidden = false
        toReceiveAmount(show: false)
    }

    func updateState() {
        [lblInfo, lblMoreInfo].forEach {
            $0.setStyle(.txt)
        }
        switch model.state {
        case .invalidAmount:
            let text = "id_invalid_amount".localized
            errorState(text: text)
        case .valid:
            disableState()
            lblAmount.isHidden = false
            if model.scope == .buyBtc {
                lblToReceiveHint.isHidden = model.hideSubamount
                lblToReceiveHint.text = model.subamountText
                if model.showMessage {
                    bg.borderColor = UIColor.gAccent()
                    infoPanel.backgroundColor = UIColor.gAccent()
                    lblInfo.text = model.message(.valid) ?? ""
                }
            }
        /*case .validFunding:
            bg.borderColor = UIColor.gAccent()
            infoPanel.backgroundColor = UIColor.gAccent().withAlphaComponent(1.0)
            let amount = model.openChannelFee
            lblInfo.text = String(format: "id_a_set_up_funding_fee_of_s_s".localized, model.toBtcText(amount) ?? "", model.toFiatText(amount) ?? "")
            lblInfo.isHidden = false
            btnFeeInfo.isHidden = false
            lblMoreInfo.isHidden = false
            lblAmount.isHidden = true
            toReceiveAmount(show: true)
            lblToReceiveHint.text = model.toReceiveAmountStr
            [lblInfo, lblMoreInfo].forEach {
                $0?.textColor = .white
            }
            btnFeeInfo.setStyle(.underline(txt: "id_read_more".localized, color: .white))
	*/
        case .aboveInboundLiquidity:
            let amount = Int64(model.breezSdk?.nodeInfo?.inboundLiquiditySatoshi ?? 0)
            let text = String(format: "The amount is above your inbound liquidity. Please type an amount lower than %@ (%@).",  model.toBtcText(amount) ?? "", model.toFiatText(amount) ?? "")
            errorState(text: text)
        case .tooHigh:
            let amount = Int64(model.breezSdk?.nodeInfo?.maxReceivableSatoshi ?? 0)
            let text = String(format: "id_you_cannot_receive_more_than_s".localized, model.toBtcText(amount) ?? "", model.toFiatText(amount) ?? "")
            errorState(text: text)
        case .tooLow:
            let amount = model.openChannelFee
            let text = String(format: "id_this_amount_is_below_the".localized, model.toBtcText(amount) ?? "", model.toFiatText(amount) ?? "")
            errorState(text: text)
        case .disabled:
            disableState()
        case .disconnected:
            let text = "id_no_lsp_connected".localized
            errorState(text: text)
        case .invalidBuy:
            lblInfo.text = model.message(.invalidBuy) ?? ""
            lblInfo.isHidden = !model.showMessage
            lblToReceiveHint.text = model.subamountText
            lblToReceiveHint.isHidden = false
            if !model.showMessage {
                bg.borderColor = UIColor.clear
                infoPanel.backgroundColor = UIColor.clear
            } else {
                bg.borderColor = UIColor.gRedWarn()
                infoPanel.backgroundColor = UIColor.gRedWarn()
            }
            lblMoreInfo.isHidden = true
            btnFeeInfo.isHidden = true
        }
    }

    @IBAction func btnFeeInfo(_ sender: Any) {
        delegate?.onFeeInfo()
    }

    @IBAction func btnInputDenomination(_ sender: Any) {
        delegate?.onInputDenomination()
    }
}
