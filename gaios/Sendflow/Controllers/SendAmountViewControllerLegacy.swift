import Foundation
import UIKit

import greenaddress
import core
import lightning

class SendAmountViewControllerLegacy: KeyboardViewController {

    @IBOutlet weak var infoBg: UIView!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoIcon: UIImageView!
    @IBOutlet weak var lblError: UILabel!

    @IBOutlet weak var infoMultiBg: UIView!
    @IBOutlet weak var infoMultiView: UIView!
    @IBOutlet weak var infoMultiIcon: UIImageView!
    @IBOutlet weak var lblMultiError: UILabel!

    @IBOutlet weak var payRequestStack: UIStackView!
    @IBOutlet weak var lblPayRequestTitle: UILabel!
    @IBOutlet weak var lblMinMax: UILabel!

    @IBOutlet weak var textBg: UIView!
    @IBOutlet weak var amountField: UITextField!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var btnClear: UIButton!

    @IBOutlet weak var lblAvailable: UILabel!
    @IBOutlet weak var lblFiat: UILabel!
    @IBOutlet weak var btnSendAllBalance: UIButton!
    @IBOutlet weak var btnDenomination: UIButton!

    @IBOutlet weak var lblFeeTitle: UILabel!
    @IBOutlet weak var lblFeeRate: UILabel!
    @IBOutlet weak var btnChangeSpeed: UIButton!
    @IBOutlet weak var lblTime: UILabel!
    @IBOutlet weak var lblNtwFee: UILabel!

    @IBOutlet weak var lblSumTotalKey: UILabel!
    @IBOutlet weak var lblSumTotalValue: UILabel!
    @IBOutlet weak var totalsView: UIStackView!
    @IBOutlet weak var lblConversion: UILabel!

    @IBOutlet weak var redepositMultiStack: UIStackView!
    @IBOutlet weak var amountStack: UIStackView!
    @IBOutlet weak var actionsStack: UIStackView!

    @IBOutlet weak var totalsSeparator: UIView!
    @IBOutlet weak var totalsSumView: UIView!
    @IBOutlet weak var changeSpeedView: UIView!
    @IBOutlet weak var networkFeeView: UIView!

    @IBOutlet weak var multiAssetCard: UIView!
    @IBOutlet weak var lblMultiAssetTitle: UILabel!
    @IBOutlet weak var iconsView: UIView!
    @IBOutlet weak var iconsStack: UIStackView!
    @IBOutlet weak var iconsStackWidth: NSLayoutConstraint!
    @IBOutlet weak var lblMultiAssetHint: UILabel!
    @IBOutlet weak var lblMultiAssetInfo: UILabel!

    @IBOutlet weak var redepositNoEditView: UIStackView!
    @IBOutlet weak var lblRedepositNoEdit: UILabel!

    @IBOutlet weak var withdrawHeader: UIView!
    @IBOutlet weak var lblWithdrawTitle: UILabel!
    @IBOutlet weak var withdrawPayStack: UIStackView!
    @IBOutlet weak var lblWithdrawPayTitle: UILabel!
    @IBOutlet weak var withdrawRangeStack: UIStackView!
    @IBOutlet weak var lblWithdrawRangeTitle: UILabel!
    @IBOutlet weak var lblFeeConvert: UILabel!
    
    @IBOutlet weak var btnSelectCoins: UIButton!

    private let iconW: CGFloat = 36.0
    var viewModel: SendAmountViewModelLegacy!

    init?(coder: NSCoder, viewModel: SendAmountViewModelLegacy) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setAmountField()
        setStyle()

        lblFeeTitle.text = "id_network_fee".localized
        lblFeeRate.text = ""
        lblTime.text = ""
        lblNtwFee.text = ""
        lblFeeConvert.text = ""
        lblSumTotalKey.text = "id_total_spent".localized
        lblSumTotalValue.text = ""
        lblError.text = ""

        [withdrawHeader, withdrawPayStack, withdrawRangeStack].forEach {
            $0?.isHidden = true
        }
        [payRequestStack, actionsStack, redepositMultiStack, btnClear].forEach {
            $0?.isHidden = false
        }

        reload()
        reloadError(false)

        Task { [weak self] in
            await self?.viewModel?.loadFees()
            await self?.validate()
            self?.reload()
        }

        //        if viewModel.assetId != viewModel.session?.gdkNetwork.getFeeAsset() {
        if viewModel.hasPrice == false {
            [lblFiat, btnDenomination, lblConversion].forEach {
                $0?.isHidden = true
            }
        }
        [changeSpeedView, networkFeeView].forEach {
            $0.isHidden = !viewModel.showFeesInTotals
        }
        [totalsSeparator, totalsSumView, lblConversion].forEach { $0.isHidden = true }
    }

    func reloadWithDraw() {
        guard let text = amountField.text else { return }

        reloadDenomination()
        reloadNavigationBar()
        reloadForLightning()

        let balance = viewModel.isFiat ? Balance.fromFiat(text, assetId: viewModel.assetId) : Balance.from(text, assetId: viewModel.assetId, denomination: viewModel.denominationType)

        viewModel.createTx.satoshi = balance?.satoshi
        lblFiat.text = "\(viewModel.subamountText ?? "")"
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
    }

    func reload() {
        reloadNavigationBar()
        configureRedeposit()
        reloadBalance()
        reloadAmount()
        reloadDenomination()
        reloadFee()
        reloadTotal()
        reloadCoinSelection()
        if viewModel.createTx.isLightning {
            reloadForLightning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if viewModel.amountEditable {
            amountField.becomeFirstResponder()
        }
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            self.anchorBottom.constant = keyboardFrame.height - 20.0
        })
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillHide(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.anchorBottom.constant = 20.0
        })
    }

    func setContent() {
        title = "id_amount".localized
        btnNext.setTitle("id_next".localized, for: .normal)
        lblPayRequestTitle.text = "id_payment_request_of".localized
        lblMultiAssetTitle.text = ""
        lblMultiAssetHint.text = "id_multiple_assets".localized
        lblMultiAssetInfo.text = "id_the_amount_cant_be_changed".localized
        lblRedepositNoEdit.text = "id_the_amount_cant_be_changed".localized
        lblAvailable.text = "Available:".localized
        btnChangeSpeed.setTitle("id_change_speed".localized, for: .normal)
    }
    
    func setAmountField() {
        amountField.delegate = self
        amountField.keyboardType = .decimalPad
        amountField.addTarget(
            self,
            action: #selector(SendAmountViewControllerLegacy.textFieldDidChange(_:)),
            for: .editingChanged
        )
    }

    var btnNextEnabled: Bool = false {
        didSet {
            btnNext.isEnabled = btnNextEnabled
            if btnNextEnabled {
                btnNext.setStyle(.primary)
            } else {
                btnNext.setStyle(.primaryDisabled)
            }
        }
    }

    func setStyle() {
        textBg.setStyle(CardStyle.defaultStyle)
        [infoBg, infoMultiBg].forEach {
            $0.cornerRadius = 4.0
        }
        [lblError, lblMultiError].forEach {
            $0.setStyle(.txt)
        }
        [lblAvailable, lblFiat, lblFeeRate, lblTime, lblConversion, lblFeeConvert].forEach {
            $0?.setStyle(.txtCard)
        }
        [lblFeeTitle, lblNtwFee].forEach {
            $0?.setStyle(.txt)
            $0?.font = UIFont.systemFont(ofSize: lblFeeTitle.font.pointSize, weight: .semibold)
        }
        lblAvailable.font = UIFont.systemFont(ofSize: lblAvailable.font.pointSize, weight: .medium)
        btnDenomination.setStyle(.inline)
        btnDenomination.setTitleColor(.white, for: .normal)
        btnDenomination.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        btnChangeSpeed.setStyle(.inline)
        [lblSumTotalKey, lblSumTotalValue].forEach {
            $0?.setStyle(.txtBigger)
        }
        btnNextEnabled = false
        [lblPayRequestTitle, lblWithdrawPayTitle, lblWithdrawRangeTitle].forEach {
            $0?.setStyle(.sectionTitle)
        }
        lblMinMax.setStyle(.txt)
        lblMinMax.text = ""

        [multiAssetCard].forEach {
            $0.cornerRadius = 4.0
        }
        lblMultiAssetHint.setStyle(.txtCard)
        lblMultiAssetInfo.setStyle(.txtCard)
        lblRedepositNoEdit.setStyle(.txtCard)

        lblWithdrawPayTitle.text = "id_amount_to_receive".localized
        lblWithdrawTitle.setStyle(.txt)
        amountField.textColor = .white

        var sendAllConfig = UIButton.Configuration.plain()
        sendAllConfig.titleLineBreakMode = .byTruncatingTail
        sendAllConfig.imagePlacement = .trailing
        sendAllConfig.imagePadding = 4.0
        sendAllConfig.baseForegroundColor = .gAccent()
        sendAllConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        sendAllConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
            return outgoing
        }
        btnSendAllBalance.configuration = sendAllConfig

        var selectCoinsConfig = UIButton.Configuration.plain()
        selectCoinsConfig.image = UIImage(resource: .icCaretRightLight).resize(20, 20)
        selectCoinsConfig.imagePlacement = .trailing
        selectCoinsConfig.imagePadding = 0
        selectCoinsConfig.baseForegroundColor = .gGrayTxt()
        selectCoinsConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        selectCoinsConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
            return outgoing
        }
        btnSelectCoins.semanticContentAttribute = .unspecified
        btnSelectCoins.configuration = selectCoinsConfig
    }

    func configureRedeposit() {
        if viewModel.redeposit2faType != nil {
            btnNext.setTitle("id_redeposit".localized, for: .normal)
            [lblAvailable, amountStack, actionsStack, totalsSeparator, totalsSumView, btnSendAllBalance, btnClear].forEach { $0?.isHidden = true }
        }
        switch viewModel.redeposit2faType {
        case .single:
            amountStack.isHidden = false
            actionsStack.isHidden = false
            redepositNoEditView.isHidden = false
            totalsSeparator.isHidden = false
            totalsSumView.isHidden = false
            redepositMultiStack.isHidden = true
        case .multi:
            redepositNoEditView.isHidden = true
            redepositMultiStack.isHidden = false
            configureMultiAssetIcons()
        case .none:
            redepositNoEditView.isHidden = true
            redepositMultiStack.isHidden = true
        }
    }

    func configureMultiAssetIcons() {
        for v in iconsStack.subviews { v.removeFromSuperview() }
        var icons = viewModel.getAssetIcons()
        icons = Array(icons.prefix(4))
        iconsStackWidth.constant = CGFloat(icons.count) * iconW - CGFloat(icons.count - 1) * 5.0
        setImages(icons)
        iconsView.isHidden = false
    }

    func setImages(_ images: [UIImage]) {
        for img in images {
            let imageView = UIImageView()
            imageView.image = img
            imageView.borderColor = UIColor.gBlackBg()
            imageView.borderWidth = 2.0
            imageView.layer.cornerRadius = iconW / 2.0
            imageView.layer.masksToBounds = true
            iconsStack.addArrangedSubview(imageView)
        }
    }
    @MainActor
    func reloadNavigationBar() {
        if viewModel.redeposit2faType != nil {
            title = "id_reenable_2fa".localized
        } else {
            if let titleView = Bundle.main.loadNibNamed("SendTitleView", owner: self, options: nil)?.first as? SendTitleView {
                let title = "\("id_send".localized) \(viewModel.assetInfo?.ticker ?? "")"
                titleView.configure(txt: title, image: viewModel.assetImage ?? UIImage())
                self.navigationItem.titleView = titleView
            }
        }
    }

    @MainActor
    func reloadError(_ error: Bool) {
        if error {
            btnNextEnabled = false
            lblError.text = viewModel.error?.localized
            lblMultiError.text = viewModel.error?.localized
            infoMultiBg.backgroundColor = UIColor.gRedWarn()
            infoBg.backgroundColor = UIColor.gRedWarn()
            infoMultiView.isHidden = false
            infoView.isHidden = false
        } else {
            btnNextEnabled = false
            if viewModel.createTx.satoshi ?? 0 > 0 || viewModel.createTx.sendAll || viewModel.createTx.txType == .sweep || viewModel.createTx.txType == .redepositExpiredUtxos {
                btnNextEnabled = true
            }
            lblError.text = ""
            lblMultiError.text = ""
            infoMultiBg.backgroundColor = .clear
            infoBg.backgroundColor = .clear
            infoMultiView.isHidden = true
            infoView.isHidden = true
        }
    }

    @IBAction func btnClear(_ sender: Any) {
        if !viewModel.amountEditable { return }
        turnOffMaxMode()
        amountField.text = ""
        viewModel.createTx.satoshi = nil
        lblFiat.text = "\(viewModel.subamountText ?? "")"
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
        amountField.becomeFirstResponder()
        Task { [weak self] in
            await self?.validate()
            self?.reloadTotal()
            self?.reloadError(false)
            self?.btnNextEnabled = false
            self?.btnClear.isHidden = true
        }
    }

    @IBAction func btnChangeSpeed(_ sender: Any) {
        view.endEditing(true)
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendDialogFeeViewController") as? SendDialogFeeViewController {
            vc.viewModel = viewModel.sendDialogFeeViewModel()
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    @IBAction func btnNext(_ sender: Any) {
        guard viewModel.transaction != nil else { return }
        presentSendTxConfirmViewController()
    }

    @IBAction func btnSelectCoins(_ sender: Any) {
        presentCoinControlViewController()
    }
    
    @MainActor
    func presentSendTxConfirmViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendTxConfirmViewController") as? SendTxConfirmViewController {
            vc.viewModel = viewModel.sendSendTxConfirmViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @MainActor
    func presentCoinControlViewController() {
        let assetId = viewModel.createTx.assetId ?? viewModel.subaccount?.gdkNetwork.getFeeAsset() ?? "btc"
        let viewModel = CoinControlViewModel(
            subaccount: viewModel.subaccount,
            assetId: assetId,
            selectedUtxos: viewModel.selectedUtxos,
            denomination: viewModel.denominationType,
            isFiat: viewModel.isFiat
        )
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "CoinControlViewController") { coder in
            CoinControlViewController(coder: coder, viewModel: viewModel)
        }
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func btnSendAll(_ sender: Any) {
        viewModel.sendAll.toggle()

        if !viewModel.sendAll {
            viewModel.createTx.satoshi = nil
            reloadAmount()
        }
        Task { [weak self] in
            await self?.validate()
            self?.reloadAmount()
        }
    }

    @IBAction func btnDenomination(_ sender: Any) {
        // Disable for liquid asset
//        if viewModel.assetId != viewModel.session?.gdkNetwork.getFeeAsset() {
//            return
//        }
        if AssetInfo.baseIds.contains(viewModel.assetId) {
            guard let model = viewModel.dialogInputDenominationViewModel() else {return}
            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
            let vc = storyboard.instantiateViewController(identifier: "DialogInputDenominationViewController") { coder in
                DialogInputDenominationViewController(coder: coder, model: model)
            }
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        } else {
            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogLiquidAssetToFiatViewController") as? DialogLiquidAssetToFiatViewController {
                vc.viewModel = viewModel.dialogLiquidAssetToFiatViewModel()
                vc.delegate = self
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: false, completion: nil)
            }
        }
    }

    func reloadForLightning() {
        lblFeeTitle.isHidden = true
        lblFeeRate.isHidden = true
        lblNtwFee.isHidden = true
        btnChangeSpeed.isHidden = true
        lblSumTotalKey.isHidden = true
        lblSumTotalValue.isHidden = true
        lblTime.isHidden = true
        totalsView.isHidden = true
        btnSendAllBalance.isHidden = true
    }

    @MainActor
    func reloadBalance() {
        if let selected = viewModel.createTx.selectedUtxos, !selected.isEmpty {
            let satoshi = selected.compactMap { $0.satoshi }.reduce(0, +)
            if let balance = Balance.fromSatoshi(satoshi, assetId: viewModel.assetId) {
                let balanceText = viewModel.isFiat ? balance.toFiatText() : balance.toText(viewModel.denominationType)
                btnSendAllBalance.setTitle(balanceText, for: .normal)
            } else {
                btnSendAllBalance.setTitle(viewModel.walletBalanceText ?? "", for: .normal)
            }
        } else {
            btnSendAllBalance.setTitle(viewModel.walletBalanceText ?? "", for: .normal)
        }
    }

    @MainActor
    func reloadAmount() {
        amountField.isUserInteractionEnabled = viewModel.amountEditable
        btnSendAllBalance.isUserInteractionEnabled = viewModel.sendAllEnabled
        amountField.text = DecimalInputSanitizer.sanitize(text: viewModel.amountText ?? "")
        lblFiat.text = "\(viewModel.subamountText ?? "")"
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
        
        if viewModel.amountEditable {
            btnClear.isHidden = amountField.text?.isEmpty ?? true
            btnClear.setImage(UIImage(resource: .icAmountClear), for: .normal)
            btnSendAllBalance.configuration?.baseForegroundColor = .gAccent()
        } else {
            btnClear.isHidden = false
            btnClear.setImage(UIImage(resource: .icLockSimpleRegular).resize(20, 20).maskWithColor(color: UIColor.gAccent()), for: .normal)
            btnSendAllBalance.setStyle(.inlineDisabled)
        }
        
        let checkImage = viewModel.sendAll ? UIImage(resource: .icCheckLight).resize(16, 16).maskWithColor(color: UIColor.gAccent()) : nil
        btnSendAllBalance.configuration?.image = checkImage

        payRequestStack.isHidden = true
        if viewModel.createTx.isLightning {
            if let minAmount = viewModel.createTx.addressee.minAmount,
               let maxAmount = viewModel.createTx.addressee.maxAmount {
                payRequestStack.isHidden = false
                lblMinMax.text = "\(minAmount) - \(maxAmount) sats"
            }
        }
    }

    @MainActor
    func reloadDenomination() {
        btnDenomination.setTitle(
            viewModel.isFiat ? viewModel?.fiatCurrency ?? "" : viewModel?.assetInfo?.ticker ?? "BTC",
            for: .normal)
    }

    @MainActor
    func reloadTotal() {
        lblSumTotalValue.text = viewModel?.totalText ?? ""
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
    }

    @MainActor
    func reloadFee() {
        lblFeeRate.text = viewModel?.feeRateText ?? ""
        lblTime.text = "~\(viewModel?.feeTimeText ?? "")"
        lblNtwFee.text = viewModel?.feeText ?? ""
        lblFeeConvert.text = viewModel?.feeConvertText ?? ""
    }
    
    @MainActor
    func reloadCoinSelection() {
        let isSupportedNetwork = viewModel.createTx.isBitcoin || viewModel.createTx.isLiquid
        let isNotBumpFee = viewModel.createTx.txType != .bumpFee

        let session = (viewModel.accountBackend as? GdkAccountBackend)?.session
        let isPolicyAsset = viewModel.assetId == session?.gdkNetwork.getFeeAsset()

        let isCoinSelectionAllowed = isSupportedNetwork && isNotBumpFee && isPolicyAsset
        btnSelectCoins.isHidden = !isCoinSelectionAllowed

        if let selectedCoins = viewModel.createTx.selectedUtxos, !selectedCoins.isEmpty {
            let coinsText = selectedCoins.count == 1 ? "Coin" : "Coins"
            btnSelectCoins.setTitle( "\(selectedCoins.count) \(coinsText)".localized, for: .normal)
            btnSelectCoins.setTitleColor(.white, for: .normal)
            btnSelectCoins.tintColor = .white
        } else {
            btnSelectCoins.setTitle("All coins".localized, for: .normal)
            btnSelectCoins.setTitleColor(.gGrayTxt(), for: .normal)
            btnSelectCoins.tintColor = .gGrayTxt()
        }
    }

    @objc func triggerTextChange() {
        Task { [weak self] in await self?.validate() }
    }

    func validate() async {
        let task = viewModel.validate()
        switch await task?.result {
        case .success(_):
            break
        case .failure(let err):
            switch err {
            case TransactionError.invalid(let localizedDescription, _):
                DropAlert().error(message: localizedDescription)
            case GaError.ReconnectError, GaError.SessionLost, GaError.TimeoutError:
                DropAlert().error(message: "id_you_are_not_connected".localized)
            default:
                DropAlert().error(message: err.description().localized)
            }
        default:
            break
        }
        if viewModel.sendAll || viewModel.createTx.txType == .sweep || viewModel.createTx.txType == .redepositExpiredUtxos {
            reloadAmount()
        }
        reloadError(viewModel.error != nil)
        reloadFee()
        reloadTotal()
    }

    func onLiquidAssetFiatChange() {
        reloadAmount()
        reloadBalance()
        reloadFee()
        reloadTotal()
        reloadNavigationBar()
        reloadDenomination()
    }
}

extension SendAmountViewControllerLegacy: DialogInputDenominationViewControllerDelegate {

    func didSelectFiat() {
        viewModel.isFiat = true
        reloadAmount()
        reloadBalance()
        reloadFee()
        reloadTotal()
        reloadNavigationBar()
        reloadDenomination()
    }

    func didSelectInput(denomination: DenominationType) {
        viewModel.denominationType = denomination
        viewModel.isFiat = false
        reloadAmount()
        reloadBalance()
        reloadFee()
        reloadTotal()
        reloadNavigationBar()
        reloadDenomination()
    }
}
extension SendAmountViewControllerLegacy {
    @objc func textFieldDidChange(_ textField: UITextField) {
        turnOffMaxMode()
        guard let text = amountField.text else { return }
        btnClear.isHidden = text.isEmpty
        if text.isEmpty {
            reloadError(false)
            btnNextEnabled = false
            return
        }
        let balance = viewModel.isFiat ? Balance.fromFiat(text, assetId: viewModel.assetId) : Balance.from(text, assetId: viewModel.assetId, denomination: viewModel.denominationType)
        viewModel.createTx.satoshi = balance?.satoshi
        lblFiat.text = "\(viewModel.subamountText ?? "")"
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"

        btnNextEnabled = false
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0.3)
    }
    
    private func turnOffMaxMode() {
        if viewModel.sendAll {
            viewModel.sendAll = false
            btnSendAllBalance.configuration?.image = nil
        }
    }
}
extension SendAmountViewControllerLegacy: SendDialogFeeViewControllerProtocol {
    func select(transactionPriority: TransactionPriority, feeRate: UInt64?) {
        viewModel.createTx.feeRate = feeRate
        viewModel.transactionPriority = transactionPriority
        reloadFee()
        reloadTotal()
        reloadAmount()
        Task { [weak self] in
            await self?.validate()
            self?.reloadAmount()
        }
    }
}
extension SendAmountViewControllerLegacy: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let currentText = textField.text ?? ""
        guard let range = Range(range, in: currentText) else { return false }

        let proposedValue = currentText.replacingCharacters(in: range, with: string)
        let sanitizedValue = DecimalInputSanitizer.sanitize(
            text: proposedValue,
            maxDecimals: viewModel.maxDecimals
        )
        
        guard sanitizedValue != proposedValue else { return true }

        if sanitizedValue != currentText {
            textField.text = sanitizedValue
            textField.sendActions(for: .editingChanged)
        }
        
        return false
    }
}
extension SendAmountViewControllerLegacy: DialogLiquidAssetToFiatViewControllerDelegate {
    func didSelectLiquidAsset() {
        viewModel.isFiat = false
        onLiquidAssetFiatChange()
    }
    func didSelectFiatConversion() {
        viewModel.isFiat = true
        onLiquidAssetFiatChange()
    }
}

extension SendAmountViewControllerLegacy: CoinControlDelegate {
    func didSelectCoins(_ utxos: [UnspentOutput]) {
        viewModel.createTx.selectedUtxos = utxos.isEmpty ? nil : utxos
        reloadBalance()
        reloadCoinSelection()
        reloadAmount()
        Task { [weak self] in
            await self?.validate()
            self?.reloadAmount()
        }
    }
}
