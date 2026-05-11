import UIKit
import gdk

enum AmountCellState: Int {
    case valid
    // case validFunding
    case aboveInboundLiquidity
    case tooHigh
    case tooLow
    case disabled
    case invalidAmount
    case disconnected
    case invalidBuy
    case invalidReverseSwap
    case lnBelowMin
    case lnAboveMax
    case lnRecommend
    case lnShowFunding
}

protocol AmountCellDelegate: AnyObject {
    func textFieldDidChange(_ satoshi: Int64?, isFiat: Bool)
    func textFieldEnabled()
    func onFeeInfo()
    func onFundingFeeInfo()
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
    @IBOutlet weak var lblConversion: UILabel!
    @IBOutlet weak var lblMoreInfo: UILabel!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnPaste: UIButton!
    @IBOutlet weak var btnSwitch: UIButton!
    @IBOutlet weak var btnEdit: UIButton!
    @IBOutlet weak var btnFeeInfo: UIButton!
    @IBOutlet weak var lblToReceiveTitle: UILabel!
    @IBOutlet weak var lblToReceiveHint: UILabel!
    @IBOutlet weak var bottomStackPad: NSLayoutConstraint!
    @IBOutlet weak var moreInfoView: UIView!

    var state: AmountCellState = .valid
    weak var delegate: AmountCellDelegate?
    var model: AmountCellModel!
    var enabled: Bool = true

    static var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        bg.borderWidth = 1.0
        bg.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
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
        btnCancel.setImage(UIImage(named: "ic_cancel")?.maskWithColor(color: UIColor.gGrayTxt()), for: .normal)
        lblConversion.text = ""
        lblConversion.setStyle(.txtCard)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
            self.textField.becomeFirstResponder()
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: AmountCellModel, delegate: AmountCellDelegate?, enabled: Bool) {
        self.delegate = delegate
        self.model = model
        self.enabled = enabled
        textField.text = model.amountText
        textField.accessibilityIdentifier = AccessibilityIds.ReceiveScreen.textFieldAmount
        lblAsset.attributedText = model.denomUnderlineText
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        if !enabled {
            state = .disabled
        }
        triggerTextChange()
    }

    func reload() {
        textField.isEnabled = enabled
        btnCancel.isHidden = !(textField.text?.count ?? 0 > 0)
        // btnCancel.isHidden = enabled
        // btnEdit.isHidden = enabled
        // btnPaste.isHidden = !enabled
        // btnPaste.isHidden = textField.text?.count ?? 0 > 0
        let balance = "\(model?.maxLimitAmount ?? "") \(model?.denomText ?? "")"
        lblAmount.text = String(format: "id_max_limit_s".localized, balance)
        if model.scope == .reverseSwap || model.scope == .ltReceive {
            lblAmount.isHidden = true
            bottomStackPad.constant = model.showMessage ? 10 : -24
        }
        lblAsset.attributedText = model?.denomUnderlineText

        btnPaste.isHidden = true // always hidden
        btnEdit.isHidden = true  // always hidden
        
        lblConversion.text = model.conversionText()
    }

    func toReceiveAmount(show: Bool) {
        [lblToReceiveTitle, lblToReceiveHint].forEach {
            $0?.isHidden = !show
        }
    }

    func getSatoshi(_ value: String) -> Int64? {
        if model.isFiat {
            let balance = Balance.fromFiat(value, assetId: AssetInfo.btcId)
            return balance?.satoshi
        } else {
            let balance = Balance.from(value, assetId: AssetInfo.btcId, denomination: model.inputDenomination)
            return balance?.satoshi
        }
    }

    @objc func triggerTextChange() {
        if let value = textField.text {
            Task.detached { [weak self] in
                let satoshi = await self?.getSatoshi(value)
                //let fee = await self?.model.buildOpenChannelFee(satoshi ?? 0)
                await MainActor.run { [weak self] in
                    self?.model.satoshi = satoshi
                    //self?.model.setOpenChannelFee(fee ?? 0)
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

    func responderOn() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
            self.textField.becomeFirstResponder()
        }
    }

    @IBAction func onEdit(_ sender: Any) {
//        enabled = true
//        reload()
//        textField.becomeFirstResponder()
//        delegate?.textFieldEnabled()
    }

    @IBAction func onSwitch(_ sender: Any) {
        delegate?.onInputDenomination()
    }

    @IBAction func btnPaste(_ sender: Any) {
//        if let text = UIPasteboard.general.string {
//            textField.text = text
//            textFieldDidChange(textField)
//        }
    }

    @IBAction func btnCancel(_ sender: Any) {

        enabled = true
        self.reload()
//        textField.becomeFirstResponder()
        self.delegate?.textFieldEnabled()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
            self.textField.text = ""
            self.textFieldDidChange(self.textField)

        }
    }

    func errorState(text: String) {
        bg.borderColor = UIColor.gRedWarn()
        infoPanel.backgroundColor = UIColor.gRedWarn()
        lblInfo.text = text
        lblInfo.isHidden = false
        lblAmount.isHidden = true
        toReceiveAmount(show: false)
    }

    func disableState() {
        bg.borderColor = UIColor.gBlackBg()
        infoPanel.backgroundColor = UIColor.clear
        // lblInfo.isHidden = true
        lblInfo.text = " "
        lblAmount.isHidden = false
        toReceiveAmount(show: false)
    }

    func updateState() {
        [lblInfo, lblMoreInfo].forEach {
            $0.setStyle(.txt)
        }
        infoPanel.borderWidth = 1
        infoPanel.borderColor = .clear
        switch model.state {
        case .invalidAmount:
            let text = "id_invalid_amount".localized
            errorState(text: text)
        case .valid:
            disableState()
            lblAmount.isHidden = false
            if model.scope == .reverseSwap {
                moreInfoView.isHidden = true
                lblToReceiveHint.isHidden = model.hideSubamount || model.isFiat
                lblToReceiveHint.text = model.subamountText
            }
        case .aboveInboundLiquidity:
            break
        case .tooHigh:
            break
        case .tooLow:
            let amount = Int64(model.minAmountOpening ?? 0)
            let text = String(format: "id_amount_must_be_at_least_s".localized, model.toBtcText(amount) ?? "")
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
        case .invalidReverseSwap:
            moreInfoView.isHidden = false
            lblInfo.text = model.message(.invalidReverseSwap) ?? ""
            lblInfo.isHidden = false
            lblToReceiveHint.text = model.subamountText
            bg.borderColor = UIColor.gRedWarn()
            infoPanel.backgroundColor = UIColor.gRedWarn()
            lblToReceiveHint.isHidden = true
        case .lnBelowMin:
            moreInfoView.isHidden = false
            lblInfo.text = model.lnMessage(model.state)
            lblInfo.isHidden = false
            bg.borderColor = UIColor.gRedWarn()
            infoPanel.backgroundColor = UIColor.gRedSwapErr1()
            infoPanel.borderColor = UIColor.gRedWarn()
        case .lnAboveMax:
            moreInfoView.isHidden = false
            lblInfo.text = model.lnMessage(model.state)
            lblInfo.isHidden = false
            bg.borderColor = UIColor.gRedWarn()
            infoPanel.backgroundColor = UIColor.gRedSwapErr1()
            infoPanel.borderColor = UIColor.gRedWarn()
        case .lnRecommend:
            moreInfoView.isHidden = false
            lblInfo.text = model.lnMessage(model.state)
            lblInfo.isHidden = false
            bg.borderColor = UIColor.gRedWarn()
            infoPanel.backgroundColor = UIColor.gWarnCardBg()
            addGesture(model.lnMessage(model.state))
            infoPanel.borderColor = UIColor.gRedWarn()
        case .lnShowFunding:
            moreInfoView.isHidden = false
            lblInfo.isHidden = false
            bg.borderColor = UIColor.gWarnCardBgBlue()
            infoPanel.backgroundColor = UIColor.gWarnCardBgBlue()
            infoPanel.borderColor = UIColor.gWarnCardBgBlue()
            addGesture(model.lnMessage(model.state))
        }
    }

    func addGesture(_ str: String) {
        let strLearnWhy = "Learn why".localized
        let pStyle = NSMutableParagraphStyle()
        pStyle.lineSpacing = 2.0
        let bAttr: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14.0),
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let attrStr = NSMutableAttributedString(string: str)
        attrStr.addAttribute (
            NSAttributedString.Key.paragraphStyle,
            value: pStyle,
            range: NSRange(location: 0, length: attrStr.length))
        attrStr.setAttributes(bAttr, for: strLearnWhy)
        lblInfo.attributedText = attrStr
        lblInfo.isUserInteractionEnabled = true
        lblInfo.lineBreakMode = .byWordWrapping
        lblInfo.textAlignment = .left
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(onTap(_:)))
        tapGesture.numberOfTouchesRequired = 1
        lblInfo.addGestureRecognizer(tapGesture)
    }

    @objc func onTap(_ sender: UITapGestureRecognizer) {
        delegate?.onFundingFeeInfo()
    }
    @IBAction func btnFeeInfo(_ sender: Any) {
        delegate?.onFeeInfo()
    }

    @IBAction func btnInputDenomination(_ sender: Any) {
        delegate?.onInputDenomination()
    }
}
