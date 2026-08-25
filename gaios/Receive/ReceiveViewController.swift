import Foundation
import UIKit
import greenaddress
import LinkPresentation
import hw
import Combine
import core
import lightning

class ReceiveViewController: KeyboardViewController {

    // scroll + stackview
    // Backup
    @IBOutlet weak var viewBackup: UIView!
    @IBOutlet weak var bgBackup: UIView!
    @IBOutlet weak var lblTitleBackup: UILabel!
    @IBOutlet weak var lblHintBackup: UILabel!
    @IBOutlet weak var btnRightBackup: UIButton!
    @IBOutlet weak var btnLeftBackup: UIButton!
    @IBOutlet weak var btnsContainerBackup: UIStackView!
    @IBOutlet weak var iconWarnBackup: UIImageView!
    @IBOutlet weak var btnDismissBackup: UIButton!
    // Asset
    @IBOutlet weak var viewAsset: UIView!
    @IBOutlet weak var bgAsset: UIView!
    @IBOutlet weak var imgViewAsset: UIImageView!
    @IBOutlet weak var lblAssetSection: UILabel!
    @IBOutlet weak var lblAssetAsset: UILabel!
    @IBOutlet weak var iconDiscloseAsset: UIImageView!
    @IBOutlet weak var viewLightReadyAsset: UIView!
    @IBOutlet weak var iconLightReadyAsset: UIImageView!
    @IBOutlet weak var lblLightReadyAsset: UILabel!
    // Account
    @IBOutlet weak var viewAccount: UIView!
    @IBOutlet weak var bgAccount: UIView!
    @IBOutlet weak var lblAccountAccount: UILabel!
    @IBOutlet weak var lblNameAccount: UILabel!
    @IBOutlet weak var iconDiscloseAccount: UIImageView!
    // Segmented
    @IBOutlet weak var viewSegmented: UIView!
    @IBOutlet weak var lblSegmentedSection: UILabel!
    @IBOutlet weak var segmented: UISegmentedControl!
    // Amount
    @IBOutlet weak var viewAmount: UIView!
    @IBOutlet weak var lblAmountSection: UILabel!
    @IBOutlet weak var bgAmount: UIView!
    @IBOutlet weak var textFieldAmount: DecimalTextField!
    @IBOutlet weak var lblAssetAmount: UILabel!
    @IBOutlet weak var lblAmountAmount: UILabel!
    @IBOutlet weak var lblInfoAmount: UILabel!
    @IBOutlet weak var infoPanelAmount: UIView!
    @IBOutlet weak var lblConversionAmount: UILabel!
    @IBOutlet weak var lblMoreInfoAmount: UILabel!
    @IBOutlet weak var btnCancelAmount: UIButton!
    @IBOutlet weak var btnSwitchAmount: UIButton!
    @IBOutlet weak var btnFeeInfoAmount: UIButton!
    @IBOutlet weak var lblToReceiveTitleAmount: UILabel!
    @IBOutlet weak var lblToReceiveHintAmount: UILabel!
    @IBOutlet weak var bottomStackPadAmount: NSLayoutConstraint!
    @IBOutlet weak var moreInfoViewAmount: UIView!
    // Address
    @IBOutlet weak var viewAddress: UIView!
    @IBOutlet weak var lblAddressSection: UILabel!
    @IBOutlet weak var bgCardAddress: UIView!
    @IBOutlet weak var bgCardQRAddress: UIView!
    @IBOutlet weak var envelopeViewAddress: UIView!
    @IBOutlet weak var envelopeBorderViewAddress: UIView!
    @IBOutlet weak var btnQRCodeAddress: UIButton!
    @IBOutlet weak var qrFrameAddress: QRCodeView!
    @IBOutlet weak var lnBannerBoxAddress: UIView!
    @IBOutlet weak var lnBannerAddress: UIView!
    @IBOutlet weak var lblInfoAddress: UILabel!
    @IBOutlet weak var btnRefreshAddress: UIButton!
    @IBOutlet weak var btnMagnifyAddress: UIButton!
    @IBOutlet weak var btnCopyAddress: UIButton!
    @IBOutlet weak var plainTxtAddress: UILabel!
    @IBOutlet weak var groupedTxtAddress: UITextView!

    /// bottom static section
    @IBOutlet weak var footerLabel: UILabel!
    @IBOutlet weak var btnShare: UIButton!
    @IBOutlet weak var btnVerify: UIButton!
    @IBOutlet weak var btnConfirm: UIButton!
    @IBOutlet weak var stackBottom: NSLayoutConstraint!

    private let swapsUnavailableView = UIView()
    weak var verifyOnDeviceViewController: HWDialogVerifyOnDeviceViewController?
    private let vm: ReceiveViewModel
    var onFinish: (() -> Void)?
    private var didNotifyFinish = false

    init?(coder: NSCoder, viewModel: ReceiveViewModel) {
        self.vm = viewModel
        super.init(coder: coder)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        bind()
        requestNewAddress()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        BackupHelper.shared
            .cleanDismissedCache(walletId: vm.mainWallet.id, position: .receive)
        onUpdate()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if vm.state.showAmountView {
            self.textFieldAmount.becomeFirstResponder()
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let didFinishFlow = isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true
        guard didFinishFlow, !didNotifyFinish else { return }
        didNotifyFinish = true
        onFinish?()
    }
    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let inset = (view.window?.safeAreaInsets.bottom ?? view.safeAreaInsets.bottom) - 5
        stackBottom.constant = keyboardFrame.height - inset
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillHide(notification: notification)
        stackBottom.constant = 0.0
    }
    func onUpdate(_ feature: RefreshReceiveFeature? = nil) {
        switch feature {
        case .denomination:
            textFieldAmount.text = vm.state.amountText
        case .segmented:
            textFieldAmount.text = vm.state.amountText
            if vm.state.showAmountView {
                self.textFieldAmount.becomeFirstResponder()
            } else {
                view.endEditing(true)
                if vm.state.type != .swapUnavailable {
                    requestNewAddress()
                }
            }
        case .address:
            resetQR()
            plainTxtAddress.isHidden = true
            groupedTxtAddress.isHidden = true
            bgCardAddress.borderWidth = 1.0
            bgCardAddress.borderColor = UIColor.gGrayCardBorder()
            var style = AddressDisplayStyle.default
            switch vm.state.anyOrAsset {
            case .anyAmpLegacy, .anyAmp:
                style = .amp
            default:
                break
            }
            if !vm.state.isBip21 && !vm.state.isLightning {
                groupedTxtAddress.isHidden = false
                AddressDisplay.configure(
                    address: vm.state.text ?? "",
                    textView: groupedTxtAddress,
                    style: style,
                    truncate: true)
            } else {
                plainTxtAddress.isHidden = false
                plainTxtAddress.text = vm.state.text
            }
            qrFrameAddress.backgroundColor = .clear
            qrFrameAddress.cornerRadius = 10.0
            if let uri = vm.state.text, !uri.isEmpty {
                qrFrameAddress.isHidden = false
                qrFrameAddress.configure(frames: [uri])
            } else {
                qrFrameAddress.stopAnimation()
                qrFrameAddress.isHidden = true
            }
            lnBannerBoxAddress.isHidden = true
        case .paymentReady:
            // enter LNInvoiceScreen
            btnConfirm.setStyle(.primary)
            if vm.state.type == .bolt11, vm.state.subaccount.isLightning {
                AnalyticsManager.shared.invoiceCreate(wallet: WalletsStorage.shared.current,
                                                      account: vm.state.subaccount)
            }
            showLightningInvoice()
        case .error(let errStr):
            btnConfirm.setStyle(.primary)
            error(errStr)
        case .none:
            break
        }
        stopLoader()
        reloadNavigationBtns()
        // Backup
        viewBackup.isHidden = !vm.showBackup
        // Account
        viewAccount.isHidden = !vm.showAccount
        // Amount
        viewAmount.isHidden = !vm.state.showAmountView
        lblAssetAmount.attributedText = vm.state.denomUnderlineText
        btnCancelAmount.isHidden = !(textFieldAmount.text?.count ?? 0 > 0)
        lblAmountAmount.isHidden = true
        lblConversionAmount.text = vm.state.conversionText()
        [lblInfoAmount, lblMoreInfoAmount].forEach {
            $0.setStyle(.txt)
        }
        lblInfoAmount.isHidden = true
        infoPanelAmount.borderWidth = 1
        infoPanelAmount.borderColor = .clear
        switch vm.fieldState {
        case .valid:
            disableState()
            if vm.state.scope == .reverseSwap {
                moreInfoViewAmount.isHidden = true
                lblToReceiveHintAmount.isHidden = vm.state.hideSubamount || vm.state.isFiat
                lblToReceiveHintAmount.text = vm.state.subamountText
            }
        case .tooLow:
            let amount = Int64(vm.state.minAmountOpening)
            let text = String(format: "id_amount_must_be_at_least_s".localized, vm.state.toBtcText(amount) ?? "")
            errorState(text: text)
        case .disabled:
            disableState()
        case .invalidReverseSwap:
            moreInfoViewAmount.isHidden = false
            lblInfoAmount.text = vm.state.message(.invalidReverseSwap) ?? ""
            lblInfoAmount.isHidden = false
            lblToReceiveHintAmount.text = vm.state.subamountText
            bgAmount.borderColor = UIColor.gRedWarn()
            infoPanelAmount.backgroundColor = UIColor.gRedWarn()
            lblToReceiveHintAmount.isHidden = true
        case .lnBelowMin:
            moreInfoViewAmount.isHidden = false
            lblInfoAmount.text = vm.state.lnMessage(vm.fieldState)
            lblInfoAmount.isHidden = false
            bgAmount.borderColor = UIColor.gRedWarn()
            infoPanelAmount.backgroundColor = UIColor.gRedSwapErr1()
            infoPanelAmount.borderColor = UIColor.gRedWarn()
        case .lnAboveMax:
            moreInfoViewAmount.isHidden = false
            lblInfoAmount.text = vm.state.lnMessage(vm.fieldState)
            lblInfoAmount.isHidden = false
            bgAmount.borderColor = UIColor.gRedWarn()
            infoPanelAmount.backgroundColor = UIColor.gRedSwapErr1()
            infoPanelAmount.borderColor = UIColor.gRedWarn()
        case .lnRecommend:
            moreInfoViewAmount.isHidden = false
            lblInfoAmount.text = vm.state.lnMessage(vm.fieldState)
            lblInfoAmount.isHidden = false
            bgAmount.borderColor = UIColor.gRedWarn()
            infoPanelAmount.backgroundColor = UIColor.gWarnCardBg()
            addAttributedString(vm.state.lnMessage(vm.fieldState))
            infoPanelAmount.borderColor = UIColor.gRedWarn()
        case .lnShowFunding:
            moreInfoViewAmount.isHidden = false
            lblInfoAmount.isHidden = false
            bgAmount.borderColor = UIColor.gWarnCardBgBlue()
            infoPanelAmount.backgroundColor = UIColor.gWarnCardBgBlue()
            infoPanelAmount.borderColor = UIColor.gWarnCardBgBlue()
            addAttributedString(vm.state.lnMessage(vm.fieldState))
        }
        // Address
        viewAddress.isHidden = !vm.state.showAddressView

        // page
        let network = vm.state.subaccount.gdkNetwork
        let swapsUnavailable = vm.state.type == .swapUnavailable
        swapsUnavailableView.isHidden = !swapsUnavailable
        btnConfirm.isHidden = swapsUnavailable || !(network.lightning || vm.state.type == .lwkSwap)
        btnShare.isHidden = swapsUnavailable || network.lightning || vm.state.type == .lwkSwap
        btnVerify.isHidden = !vm.state.showVerify
        btnConfirm.isEnabled = vm.isConfirmEnabled
        btnConfirm.setStyle( btnConfirm.isEnabled ? .primary : .primaryDisabled)
        switch vm.state.type {
        case .address, .swapUnavailable:
            btnConfirm.setTitle("id_confirm".localized, for: .normal)
        case .bolt11, .lwkSwap:
            btnConfirm.setTitle("id_create_invoice".localized, for: .normal)
        }
        footerLabel.isHidden = vm.state.type != .lwkSwap
    }
    func addAttributedString(_ str: String) {
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
        lblInfoAmount.attributedText = attrStr
    }
    func errorState(text: String) {
        bgAmount.borderColor = UIColor.gRedWarn()
        infoPanelAmount.backgroundColor = UIColor.gRedWarn()
        lblInfoAmount.text = text
        lblInfoAmount.isHidden = false
        lblAmountAmount.isHidden = true
        toReceiveAmount(show: false)
    }
    func disableState() {
        bgAmount.borderColor = UIColor.gBlackBg()
        infoPanelAmount.backgroundColor = UIColor.clear
        // lblInfo.isHidden = true
        lblInfoAmount.text = " "
        lblAmountAmount.isHidden = false
        toReceiveAmount(show: false)
    }
    func toReceiveAmount(show: Bool) {
        [lblToReceiveTitleAmount, lblToReceiveHintAmount].forEach {
            $0?.isHidden = !show
        }
    }
    func resetQR() {
        qrFrameAddress.reset()
        qrFrameAddress.isHidden = true
        plainTxtAddress.isHidden = true
        groupedTxtAddress.isHidden = true
        lnBannerBoxAddress.isHidden = true
    }
    func requestNewAddress() {
        vm.newAddress()
    }
    func requestNewPayment() {
        vm.newPayment()
    }
    func showLightningInvoice() {
        vm.onShowInvoice()
    }
    func imgToShare() async -> UIImage {
        guard let text = vm.state.text else { return UIImage() }
        let frame = CGRect(x: 0.0, y: 0.0, width: 256, height: 256)
        return await QRGenerator()
            .generateStatic(text: text, size: frame.size, padding: 16, screenScale: UIScreen.main.scale) ?? UIImage()
    }
    func optRequestAmount() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAmountViewController") as? DialogAmountViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.account = vm.state.subaccount
            vc.prefill = vm.state.satoshi
            present(vc, animated: false, completion: nil)
        }
    }

    func optSweep() {
        vm.onSend()
    }
    func optAddressAuth() {
        vm.onAddressAuth()
    }
    @objc func onFundingFeeInfo(_ sender: UITapGestureRecognizer) {
        vm.onFundingFee()
    }
    @objc func textFieldDidChange(_ textField: UITextField) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0)
    }
    @objc func triggerTextChange() {
        if let txt = textFieldAmount.text {
            vm.onAmountFieldChange(txt)
        }
    }
    @objc func copyToClipboard(_ sender: Any? = nil) {
        guard let text = vm.state.text else { return }
        let data = AnalyticsManager.ReceiveAddressData(type: vm.isBipAddress(text) ? AnalyticsManager.ReceiveAddressType.uri : AnalyticsManager.ReceiveAddressType.address,
                                                       media: AnalyticsManager.ReceiveAddressMedia.text,
                                                       method: AnalyticsManager.ReceiveAddressMethod.copy)
        AnalyticsManager.shared.receiveAddress(wallet: WalletsStorage.shared.current,
                                               account: vm.state.subaccount,
                                               data: data)
        UIPasteboard.general.string = text
        DropAlert().info(message: "id_address_copied_to_clipboard".localized, delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    func onMagnify() {
        let storyboard = UIStoryboard(name: "Qrcode", bundle: nil)
        let config = MagnifyQRConfiguration(
            qrTxt: vm.state.text,
            textDisplay: .formattedAddress(text: vm.state.text ?? "")
        )
        let vc = storyboard.instantiateViewController(identifier: "MagnifyQRViewController") { coder in
            MagnifyQRViewController(coder: coder, configuration: config)
        }
        vc.modalPresentationStyle = .overFullScreen
        self.present(vc, animated: false, completion: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    @MainActor
    func error(_ err: String) {
        var msg = err
        if msg.contains("Swap in progress") {
            msg = "id_there_is_already_a_swap_in"
        }
        let alert = UIAlertController(
            title: "id_error".localized,
            message: msg.localized,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_contact_support".localized, style: .default) { _ in
            self.presentDialogErrorViewController(errStr: msg)
        })
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { _ in })
        self.present(alert, animated: true, completion: nil)
    }
    @MainActor
    func presentDialogErrorViewController(errStr: String) {
        let request = ZendeskErrorRequest(
            error: errStr,
            network: vm.state.subaccount.networkId,
            paymentHash: nil,
            screenName: "Receive")
        presentContactUsViewController(request: request)
    }
    @MainActor
    func presentConnectViewController() {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogConnectViewController") as? HWDialogConnectViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    @IBAction func btnDismissBackup(_ sender: Any) {
        vm.dismissBackupCard()
    }
    @IBAction func btnLeftBackup(_ sender: Any) {
        vm.onManualBackup()
    }
    @IBAction func onSegmentedTap(_ sender: Any) {
        if segmented.selectedSegmentIndex == 0 {
            vm.selectAddressMode()
        } else {
            vm.selectReverseSwapMode()
            AnalyticsManager.shared.swapToggle(wallet: WalletsStorage.shared.current,
                                               from: SwapChainName.lightning.rawValue,
                                               to: vm.state.subaccount.gdkNetwork.liquid ? SwapChainName.liquid.rawValue : SwapChainName.mainnet.rawValue)
        }
    }
    @IBAction func btnCancelAmount(_ sender: Any) {
        textFieldAmount.text = ""
        triggerTextChange()
    }
    @IBAction func btnInputDenomination(_ sender: Any) {
        vm.onInputDenomination()
    }
    @IBAction func btnRefreshAddress(_ sender: Any) {
        requestNewAddress()
    }
    @IBAction func btnMagnifyAddress(_ sender: Any) {
        onMagnify()
    }
    @IBAction func btnCopyAddress(_ sender: Any) {
        copyToClipboard()
    }
    @IBAction func btnQRCodeAddress(_ sender: Any) {
        copyToClipboard()
    }
    @IBAction func btnShare(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "id_share".localized,
                                               type: .sharePrefs,
                                               items: SharePrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    @IBAction func btnVerify(_ sender: Any) {
        presentConnectViewController()
    }
    @IBAction func btnConfirm(_ sender: Any) {
        if vm.state.type == .bolt11 || vm.state.type == .lwkSwap {
            startLoader()
            requestNewPayment()
            btnConfirm.setStyle(.primaryDisabled)
            AnalyticsManager.shared.swapReceive(
                wallet: WalletsStorage.shared.current,
                from: SwapChainName.lightning.rawValue,
                to: vm.state.subaccount.gdkNetwork.liquid ? SwapChainName.liquid.rawValue : SwapChainName.mainnet.rawValue
            )
        }
    }
}
extension ReceiveViewController {
    func bind() {
        vm.onUpdate = { [weak self] feature in
            self?.onUpdate(feature)
        }
    }
    func configureUI() {
        // scroll + stackview
        // Backup
        bgBackup.layer.cornerRadius = 5.0
        [btnLeftBackup, btnRightBackup].forEach { $0?.setStyle(.outlinedWhite) }
        btnLeftBackup.backgroundColor = .white
        btnLeftBackup.setTitleColor(UIColor.gBlackBg(), for: .normal)
        bgBackup.borderWidth = 1
        lblTitleBackup.setStyle(.txtBigger)
        lblHintBackup.setStyle(.txtCard)
        lblTitleBackup.text = "id_back_up_your_wallet_now".localized
        lblHintBackup.text = "id_dont_lose_access_to_your_funds".localized
        btnLeftBackup.setTitle("id_back_up_now".localized, for: .normal)
        btnRightBackup.isHidden = true
        iconWarnBackup.image = UIImage(named: "ic_card_warn")
        bgBackup.backgroundColor = UIColor.gWarnCardBg()
        bgBackup.borderColor = UIColor.gWarnCardBorder()
        // Asset
        bgAsset.setStyle(CardStyle.defaultStyle)
        lblAssetSection.setStyle(.txtSectionHeader)
        lblAssetSection.text = "id_asset".localized
        lblAssetAsset.text = vm.state.assetName
        imgViewAsset?.image = vm.state.assetIcon
        // self.onTap = onTap
        iconDiscloseAsset.isHidden = true // onTap == nil
        if vm.state.isLBTC() && vm.hasLwkSession &&
            SwapAvailability.isCreationEnabled(.init(from: .lightning, to: .liquid)) {
            configureLightningReady()
        } else {
            viewLightReadyAsset.isHidden = true
        }
        // Account
        [lblAccountAccount, lblNameAccount].forEach {
            $0.setStyle(.sectionTitle)
        }
        lblAccountAccount.text = "\("id_account".localized): \(vm.state.subaccount.localizedName)"
        // Segmented
        lblSegmentedSection.setStyle(.txtSectionHeader)
        lblSegmentedSection.text = "Payer Sends".localized
        segmented.setTitle("Liquid", forSegmentAt: 0)
        segmented.setTitle("Lightning", forSegmentAt: 1)
        segmented.selectedSegmentIndex = vm.state.selectedSegment
        viewSegmented.isHidden = !vm.showSegmented
        configureSwapsUnavailableView()
        // Amount
        textFieldAmount.text = vm.state.amountText
        lblAmountSection.setStyle(.txtSectionHeader)
        lblAmountSection.text = "Receive Amount".localized
        bgAmount.cornerRadius = 5.0
        bgAmount.borderWidth = 1.0
        bgAmount.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        lblAmountAmount.setStyle(.txtCard)
        lblAssetAmount.setStyle(.txtBigger)
        [lblToReceiveTitleAmount, lblToReceiveHintAmount].forEach {
            $0?.setStyle(.sectionTitle)
            $0?.text = ""
        }
        lblToReceiveTitleAmount.text = "id_amount_to_receive".localized
        lblMoreInfoAmount.text = "id_for_more_information".localized
        btnFeeInfoAmount.setStyle(.underline(txt: "id_read_more".localized, color: .white))
        lblToReceiveHintAmount.text = ""
        lblInfoAmount.text = ""
        lblAmountAmount.text = ""
        lblMoreInfoAmount.isHidden = true
        btnFeeInfoAmount.isHidden = true
        lblToReceiveTitleAmount.isHidden = true
        lblToReceiveHintAmount.isHidden = true
        btnCancelAmount.setImage(UIImage(named: "ic_cancel")?.maskWithColor(color: UIColor.gGrayTxt()), for: .normal)
        lblConversionAmount.text = ""
        lblConversionAmount.setStyle(.txtCard)
        textFieldAmount.accessibilityIdentifier = AccessibilityIds.ReceiveScreen.textFieldAmount
        textFieldAmount.maxDecimalsProvider = { [weak self] in self?.vm.state.maxDecimals }
        textFieldAmount.keyboardType = .decimalPad
        textFieldAmount.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        lblInfoAmount.isUserInteractionEnabled = true
        lblInfoAmount.isAccessibilityElement = true
        lblInfoAmount.accessibilityTraits = .button
        lblInfoAmount.accessibilityIdentifier = AccessibilityIds.ReceiveScreen.lblLearnWhy
        lblInfoAmount.lineBreakMode = .byWordWrapping
        lblInfoAmount.textAlignment = .left
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(onFundingFeeInfo(_:)))
        tapGesture.numberOfTouchesRequired = 1
        lblInfoAmount.addGestureRecognizer(tapGesture)
        // Address
        viewAddress.isHidden = !vm.state.showAddressView
        lblAddressSection.setStyle(.txtSectionHeader)
        lblAddressSection.text = "Address".localized
        bgCardAddress.setStyle(CardStyle.defaultStyle)
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        qrFrameAddress.addGestureRecognizer(longPressRecognizer)
        btnQRCodeAddress.accessibilityIdentifier = AccessibilityIds.ReceiveScreen.btnQRCode
        lnBannerAddress.backgroundColor = UIColor.gAccent()
        lnBannerAddress.cornerRadius = 5.0
        lblInfoAddress.setStyle(.txtCard)
        lblInfoAddress.textColor = .black
        lnBannerBoxAddress.isHidden = true
        envelopeBorderViewAddress.backgroundColor = .clear
        envelopeBorderViewAddress.borderWidth = 5.0
        switch vm.state.anyOrAsset {
        case .anyAmpLegacy, .anyAmp:
            envelopeBorderViewAddress.borderColor = UIColor.gAmp()
        default:
            envelopeBorderViewAddress.borderColor = UIColor.gAccent()
        }
        envelopeBorderViewAddress.cornerRadius = 20.0
        btnMagnifyAddress.setTitle("id_increase_qr_size".localized, for: .normal)
        btnCopyAddress.setTitle("id_copy_address".localized, for: .normal)
        [btnMagnifyAddress, btnCopyAddress].forEach {
            $0.setStyle(.blackWithImg)
        }
        plainTxtAddress.lineBreakMode = .byTruncatingTail
        resetQR()

        /// page
        title = "id_receive".localized
        btnShare.setTitle("id_share".localized, for: .normal)
        btnVerify.setTitle("id_verify_on_device".localized, for: .normal)
        switch vm.state.type {
        case .address, .swapUnavailable:
            btnConfirm.setTitle("id_confirm".localized, for: .normal)
        case .bolt11, .lwkSwap:
            btnConfirm.setTitle("id_create_invoice".localized, for: .normal)
        }
        footerLabel.text = "You will receive Liquid bitcoin via Lightning invoice.".localized
        footerLabel.isHidden = vm.state.type != .lwkSwap
        btnShare.setStyle(!vm.state.showVerify ? .primary : .outlined)
        btnVerify.setStyle(.primary)
        btnVerify.isHidden = !vm.state.showVerify
        footerLabel.setStyle(.txt)
    }
    func reloadNavigationBtns() {
        let helpButton = UIButton(type: .system)
        helpButton.setImage(UIImage(named: "ic_help"), for: .normal)
        helpButton.addTarget(self, action: #selector(helpButtonTapped), for: .touchUpInside)
        if vm.state.subaccount.networkId.lightning {
            let btnNote = UIButton(type: .system)
            btnNote.setStyle(.inline)
            btnNote.setTitle(Common.noteActionName(vm.state.description ?? ""), for: .normal)
            btnNote.addTarget(self, action: #selector(editNoteBtnTapped), for: .touchUpInside)
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: btnNote)
        } else {
            // Hide the menu when this account has no supported receive options.
            let options = MoreOptPrefs.getPrefs(
                account: vm.state.subaccount,
                assetId: vm.state.anyOrAsset.assetId
            )
            guard !options.isEmpty else {
                navigationItem.rightBarButtonItem = UIBarButtonItem(customView: helpButton)
                return
            }
            let optBtn = UIButton(type: .system)
            optBtn.setImage(UIImage(named: "ic_dots_three"), for: .normal)
            optBtn.addTarget(self, action: #selector(optBtnTap), for: .touchUpInside)
            navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: optBtn), UIBarButtonItem(customView: helpButton)]
        }
    }
    func verifyAddress() async {
        AnalyticsManager.shared.verifyAddressJade(wallet: WalletsStorage.shared.current, account: vm.state.subaccount)
        if let vm = vm.receiveVerifyOnDeviceViewModel() {
            presentVerifyOnDeviceViewController(viewModel: vm)
        }
        do {
            let success = try await vm.validateHW()
            verifyOnDeviceViewController?.dismiss()
            switch success {
            case true:
                DropAlert().success(message: "id_the_address_is_valid".localized)
            case false:
                DropAlert().error(message: "id_the_addresses_dont_match".localized)
            }
        } catch {
            verifyOnDeviceViewController?.dismiss()
            DropAlert().error(message: error.description().localized)
        }
    }
    @MainActor
    func presentVerifyOnDeviceViewController(viewModel: HWDialogVerifyOnDeviceViewModel) {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogVerifyOnDeviceViewController") as? HWDialogVerifyOnDeviceViewController {
            vc.viewModel = viewModel
            verifyOnDeviceViewController = vc
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    @objc func helpButtonTapped(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.receiveHelp)
    }
    @objc func editNoteBtnTapped() {
        vm.editNote()
    }
    @objc func optBtnTap() {
        // vm.dialogOptions()
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            let options = MoreOptPrefs.getItems(account: vm.state.subaccount, assetId: vm.state.anyOrAsset.assetId)
            let model = DialogListViewModel(
                title: "id_more_options".localized,
                type: .moreOptPrefs,
                items: options)
            vc.viewModel = model
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    func configureSwapsUnavailableView() {
        guard swapsUnavailableView.superview == nil,
              let stack = viewSegmented.superview as? UIStackView,
              let segmentedIndex = stack.arrangedSubviews.firstIndex(of: viewSegmented) else { return }

        swapsUnavailableView.accessibilityIdentifier = AccessibilityIds.ReceiveScreen.swapsUnavailable

        let cardView = UIView()
        cardView.backgroundColor = UIColor.gWarnCardBgBlue()
        cardView.cornerRadius = 8
        cardView.borderWidth = 1
        cardView.borderColor = UIColor.gWarnCardBorderBlue()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        swapsUnavailableView.addSubview(cardView)

        let icon = UIImageView(image: UIImage(named: "ic_card_warn_blue"))
        icon.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "Lightning Unavailable"
        titleLabel.numberOfLines = 0
        titleLabel.setStyle(.txtBigger)

        let bodyLabel = UILabel()
        bodyLabel.text = "Receiving Lightning payments as Liquid Bitcoin is temporarily disabled."
        bodyLabel.numberOfLines = 0
        bodyLabel.setStyle(.txtCard)
        bodyLabel.textColor = UIColor.gGrayTxt()

        let learnMoreButton = UIButton(type: .system)
        learnMoreButton.contentHorizontalAlignment = .left
        learnMoreButton.setStyle(.underline(txt: "id_learn_more".localized, color: UIColor.gAccent()))
        learnMoreButton.setImage(UIImage(named: "ic_learn_more")?.withRenderingMode(.alwaysTemplate), for: .normal)
        learnMoreButton.tintColor = UIColor.gAccent()
        learnMoreButton.semanticContentAttribute = .forceRightToLeft
        learnMoreButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        learnMoreButton.addTarget(self, action: #selector(swapsUnavailableLearnMore), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, learnMoreButton])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.setCustomSpacing(12, after: bodyLabel)

        let contentStack = UIStackView(arrangedSubviews: [icon, textStack])
        contentStack.axis = .horizontal
        contentStack.alignment = .top
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: swapsUnavailableView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: swapsUnavailableView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: swapsUnavailableView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: swapsUnavailableView.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
        stack.insertArrangedSubview(swapsUnavailableView, at: segmentedIndex + 1)
        swapsUnavailableView.isHidden = true
    }

    @objc func swapsUnavailableLearnMore() {
        SafeNavigationManager.shared.navigate(ExternalUrls.swapsUnavailable)
    }
    func configureLightningReady() {
        viewLightReadyAsset.isHidden = false
        iconLightReadyAsset.image = UIImage(named: "ic_shortcut_light")!.maskWithColor(color: .gLightning())
        lblLightReadyAsset.text = "Lightning Ready".localized
        viewLightReadyAsset.borderWidth = 1.0
        viewLightReadyAsset.borderColor = .gLightning()
        viewLightReadyAsset.cornerRadius = 5.0
        lblLightReadyAsset.setStyle(.txtSmaller)
        lblLightReadyAsset.textColor = .gLightning()
    }
    @objc func longPressAction(_ sender: UILongPressGestureRecognizer) {
        onMagnify()
    }
}
extension ReceiveViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .moreOptPrefs:

            if let item = MoreOptPrefs.getPrefs(account: vm.state.subaccount, assetId: vm.state.anyOrAsset.assetId)[safe: index] {
                switch item {
                case .requestAmount:
                    optRequestAmount()
                case .sweep:
                    optSweep()
                case .addressAuth:
                    optAddressAuth()
                }
            }
        case .sharePrefs:

            switch SharePrefs(rawValue: index) {
            case .none:
                return
            case .address:
                let uri = vm.state.text
                let activityViewController = UIActivityViewController(activityItems: [uri ?? ""], applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = self.view
                self.present(activityViewController, animated: true, completion: nil)
                let data = AnalyticsManager.ReceiveAddressData(
                    type: vm.isBipAddress(uri ?? "") ? AnalyticsManager.ReceiveAddressType.uri : AnalyticsManager.ReceiveAddressType.address,
                    media: AnalyticsManager.ReceiveAddressMedia.text,
                    method: AnalyticsManager.ReceiveAddressMethod.share)
                AnalyticsManager.shared.receiveAddress(
                    wallet: WalletsStorage.shared.current,
                    account: vm.state.subaccount,
                    data: data)
            case .qr:
                let uri = vm.state.text
                let data = AnalyticsManager.ReceiveAddressData(
                    type: vm.isBipAddress(uri ?? "") ? AnalyticsManager.ReceiveAddressType.uri : AnalyticsManager.ReceiveAddressType.address,
                    media: AnalyticsManager.ReceiveAddressMedia.image,
                    method: AnalyticsManager.ReceiveAddressMethod.share)
                AnalyticsManager.shared.receiveAddress(
                    wallet: WalletsStorage.shared.current,
                    account: vm.state.subaccount,
                    data: data)
                Task {
                    let image = await imgToShare()
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        let share = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                        if let popover = share.popoverPresentationController {
                            popover.sourceView = self.view
                            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                            popover.permittedArrowDirections = .any
                        }
                        self.present(share, animated: true, completion: nil)
                    }

                }
            case .invoice:
                break
            }
        default:
            break
        }
    }
}
extension ReceiveViewController: DialogAmountViewControllerDelegate {
    func didConfirm(satoshi: Int64?) {
        vm.setAmount(satoshi, feature: .address)
    }
    func didCancel() { }
}
extension ReceiveViewController: HWDialogConnectViewControllerDelegate {
    func connected() {}

    func logged() {
        Task { [weak self] in
            await self?.verifyAddress()
        }
    }

    func cancel() {
        error(HWError.Abort("id_cancel").description())
    }

    func failure(err: Error) {
        error(err.description())
    }
}
