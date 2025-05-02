import Foundation
import UIKit
import core
import gdk
import greenaddress
import BreezSDK
import lightning

class SendTxConfirmViewController: UIViewController {

    @IBOutlet weak var assetCard: UIView!
    @IBOutlet weak var addressCard: UIView!
    @IBOutlet weak var amountCard: UIView!
    @IBOutlet weak var amountMultiAddrCard: UIView!
    @IBOutlet weak var payRequestByCard: UIView!
    @IBOutlet weak var notesCard: UIView!

    @IBOutlet weak var iconAsset: UIImageView!
    @IBOutlet weak var iconType: UIImageView!
    @IBOutlet weak var lblAssetTitle: UILabel!
    @IBOutlet weak var lblAddressTitle: UILabel!
    @IBOutlet weak var lblAmountTitle: UILabel!
    @IBOutlet weak var addressTextView: UITextView!
    @IBOutlet weak var lblAmountValue: UILabel!
    @IBOutlet weak var lblAmountFee: UILabel!
    @IBOutlet weak var lblAssetName: UILabel!
    @IBOutlet weak var lblAccount1: UILabel!
    @IBOutlet weak var lblAccount2: UILabel!
    @IBOutlet weak var squareSliderView: SquareSliderView!

    @IBOutlet weak var lblSumFeeKey: UILabel!
    @IBOutlet weak var lblSumFeeValue: UILabel!
    @IBOutlet weak var lblSumAmountKey: UILabel!
    @IBOutlet weak var lblSumAmountValue: UILabel!
    @IBOutlet weak var lblSumAmountView: UIView!
    @IBOutlet weak var lblSumTotalKey: UILabel!
    @IBOutlet weak var lblSumTotalValue: UILabel!
    @IBOutlet weak var totalsView: UIStackView!
    @IBOutlet weak var lblConversion: UILabel!

    @IBOutlet weak var payRequestByStack: UIStackView!

    @IBOutlet weak var payRequestByImg: UIImageView!
    @IBOutlet weak var lblPayRequestByTitle: UILabel!
    @IBOutlet weak var lblPayRequestByValue: UILabel!
    @IBOutlet weak var lblPayRequestByHint: UILabel!

    @IBOutlet weak var noteView: UIStackView!
    @IBOutlet weak var lblNoteTitle: UILabel!
    @IBOutlet weak var lblNoteTxt: UILabel!
    @IBOutlet weak var btnInfoFee: UIButton!
    @IBOutlet weak var btnVerifyAddress: UIButton!
    @IBOutlet weak var btnSignViaQr: UIButton!

    let qrFlowNav = UINavigationController()

    @IBOutlet weak var lblMultiAddrHint: UILabel!
    @IBOutlet weak var iconsView: UIView!
    @IBOutlet weak var iconsStack: UIStackView!
    @IBOutlet weak var iconsStackWidth: NSLayoutConstraint!
    private let iconW: CGFloat = 36.0

    var viewModel: SendTxConfirmViewModel!
    weak var verifyOnDeviceViewController: HWDialogVerifyOnDeviceViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        squareSliderView.delegate = self
        setContent()
        setStyle()
        reload()
        updateVerifyAddressState()
    }

    func setContent() {
        if viewModel.isWithdraw {
            title = "id_withdraw".localized
        } else {
            title = "id_confirm_transaction".localized
        }

        lblAssetTitle.text = "id_account__asset".localized
        lblAddressTitle.text = viewModel.addressTitle.localized
        lblAmountTitle.text = viewModel.amountTitle.localized
        lblAmountValue.text = ""
        lblAmountFee.text = ""
        lblAssetName.text = ""
        lblAccount1.text = ""
        lblAccount2.text = ""

        lblSumFeeKey.text = "id_network_fee".localized
        lblSumFeeValue.text = ""
        lblSumAmountKey.text = "Recipient Receives".localized
        lblSumAmountValue.text = ""
        lblSumTotalKey.text = "id_total_spent".localized
        lblSumTotalValue.text = ""
        lblNoteTitle.text = "id_my_notes".localized
        lblNoteTxt.text = ""

        lblPayRequestByTitle.text = "id_payment_requested_by_s".localized
        lblPayRequestByValue.text = ""
        lblPayRequestByHint.text = ""
        payRequestByStack.isHidden = true
        lblMultiAddrHint.text = "id_multiple_assets".localized
        btnSignViaQr.setTitle("id_sign_transaction_via_qr".localized, for: .normal)
        btnSignViaQr.isHidden = !viewModel.enableExportPsbt()
        squareSliderView.isHidden = viewModel.enableExportPsbt()
    }

    func setStyle() {
        [assetCard, addressCard, amountCard, amountMultiAddrCard, notesCard, payRequestByCard].forEach {
            $0?.cornerRadius = 4.0
        }
        [lblAssetTitle, lblAddressTitle, lblAmountTitle, lblPayRequestByTitle, lblNoteTitle].forEach {
            $0?.setStyle(.sectionTitle)
        }
        lblAmountValue.setStyle(.title)
        lblAmountFee.setStyle(.txtCard)
        lblAssetName.setStyle(.txtBigger)
        [lblAccount1, lblAccount2].forEach {
            $0?.setStyle(.txtCard)
        }
        [lblSumFeeKey, lblSumFeeValue, lblSumAmountKey, lblSumAmountValue, lblNoteTxt, lblConversion].forEach {
            $0?.setStyle(.txtCard)
        }
        [lblSumTotalKey, lblSumTotalValue].forEach {
            $0?.setStyle(.txtBigger)
        }
        lblPayRequestByValue.setStyle(.txtBigger)
        lblPayRequestByHint.setStyle(.txt)
        btnInfoFee.setImage(UIImage(named: "ic_lightning_info_err")!.maskWithColor(color: UIColor.gW40()), for: .normal)
        if viewModel.isWithdraw {
            [addressCard, lblAddressTitle].forEach {
                $0.isHidden = true
            }
        }
        lblMultiAddrHint.setStyle(.txtCard)
        btnSignViaQr.setStyle(.primary)
    }

    @MainActor
    func updateVerifyAddressState() {
        btnVerifyAddress.isHidden = false
        btnVerifyAddress.backgroundColor = UIColor.clear
        btnVerifyAddress.setTitleColor(UIColor.white, for: .normal)
        btnVerifyAddress.layer.borderWidth = 1.0
        btnVerifyAddress.cornerRadius = 5.0
        btnVerifyAddress.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        switch viewModel.verifyAddressState {
        case .noneed:
            btnVerifyAddress.isHidden = true
        case .unverified:
            btnVerifyAddress.borderColor = .white
            btnVerifyAddress.setImage(UIImage(), for: .normal)
            btnVerifyAddress.setTitle("Verify address on device".localized, for: .normal)
        case .verified:
            btnVerifyAddress.isUserInteractionEnabled = false
            btnVerifyAddress.borderColor = .gray
            btnVerifyAddress.setTitle("id_address_verified".localized, for: .normal)
            btnVerifyAddress.setImage(UIImage(named: "ic_check_circle")?.maskWithColor(color: .white), for: .normal)
        }
    }

    @MainActor
    func dismissVerifyOnDeviceViewController() async {
        await verifyOnDeviceViewController?.dismissAsync(animated: true)
    }

    func verifySingleAddress(_ address: Address) async throws {
        if let vm = viewModel.sendVerifyOnDeviceViewModel(address) {
            await presentVerifyOnDeviceViewController(viewModel: vm)
        }
        do {
            let res = try await viewModel.validateHW(address)
            if res == false {
                throw TransactionError.invalid(localizedDescription: "id_the_addresses_dont_match")
            }
            await dismissVerifyOnDeviceViewController()
        } catch {
            await dismissVerifyOnDeviceViewController()
            throw TransactionError.invalid(localizedDescription: "id_the_addresses_dont_match")
        }
    }

    @IBAction func btnVerifyAddress(_ sender: Any) {
        Task {
            do {
                for address in viewModel.txAddresses ?? [] {
                    try await verifySingleAddress(address)
                }
                await MainActor.run {
                    viewModel.verifyAddressState = .verified
                    updateVerifyAddressState()
                    DropAlert().success(message: "id_the_address_is_valid".localized)
                }
            } catch {
                DropAlert().error(message: error.description()?.localized ?? "")
            }
        }
    }

    @MainActor
    func presentVerifyOnDeviceViewController(viewModel: HWDialogVerifyOnDeviceViewModel) async {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogVerifyOnDeviceViewController") as? HWDialogVerifyOnDeviceViewController {
            vc.viewModel = viewModel
            verifyOnDeviceViewController = vc
            vc.modalPresentationStyle = .overFullScreen
            await presentAsync(vc, animated: false)
        }
    }

    func reload() {
        updateNavigationItem()
        lblAmountValue.text = viewModel.amountText
        lblAmountFee.text = "≈ \(viewModel.subamountText ?? "")"
        lblAssetName.text = viewModel.asset?.name ?? viewModel.assetId
        lblAccount1.text = viewModel.subaccount?.localizedName.uppercased()
        lblAccount2.text = viewModel.subaccount?.type.shortText.uppercased()
        iconAsset.image = viewModel.assetImage
        iconType.image = networkImage(viewModel.subaccount?.networkType ?? .bitcoinSS)

        lblSumFeeValue.text = viewModel.feeText
        lblSumAmountValue.text = viewModel.amountText
        lblSumTotalValue.text = viewModel.totalText
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
        lblNoteTxt.text = viewModel.note
        totalsView.isHidden = viewModel.isLightning
        noteView.isHidden = viewModel.isLightning && viewModel.note == nil
        noteView.isHidden = viewModel.note?.isEmpty ?? true
        lblSumAmountView.isHidden = viewModel.recipientReceivesHidden
        amountMultiAddrCard.isHidden = true

        if viewModel.isLightning {
            if let text = viewModel.addressee?.domain {
                lblPayRequestByValue.text = text
            }
            if let metadata = viewModel.addressee?.metadata {
                lblPayRequestByHint.text = metadata.desc ?? metadata.plain ?? ""
            }
            if let imageBase64 = viewModel.addressee?.metadata?.image {
                payRequestByImg.image = UIImage(base64: imageBase64)
            } else {
                payRequestByImg.isHidden = true
            }
            payRequestByStack.isHidden = viewModel.addressee?.domain == nil
            addressTextView.text = viewModel.address ?? ""
            addressTextView.textContainer.maximumNumberOfLines = 1
            addressTextView.textContainer.lineBreakMode = .byTruncatingMiddle
        } else if viewModel.multiAddressees {
            payRequestByStack.isHidden = true
            addressTextView.text = "Multiple addresses".localized
            lblAssetName.text = "id_multiple_assets".localized
            amountCard.isHidden = true
            amountMultiAddrCard.isHidden = false
            lblMultiAddrHint.text = "id_multiple_assets".localized
            configureMultiAddrIcons()
            lblAmountFee.text = ""
            totalsView.isHidden = false
            lblSumTotalValue.text = viewModel.feeText
        } else {
            payRequestByStack.isHidden = true
            AddressDisplay.configure(
                address: viewModel.address ?? "",
                textView: addressTextView)
        }
        if viewModel.assetId != viewModel.session?.gdkNetwork.getFeeAsset() {
            [lblConversion, lblAmountFee].forEach {
                $0?.isHidden = true
            }
        }
    }

    func networkImage(_ network: NetworkSecurityCase) -> UIImage? {
        if network.lightning {
            return UIImage(named: "ic_lightning")
        } else if network.multisig {
            return UIImage(named: "ic_key_ms")
        } else {
            return UIImage(named: "ic_key_ss")
        }
    }

    func configureMultiAddrIcons() {
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
    func updateNavigationItem() {
        let noteBtn = UIButton(type: .system)
        noteBtn.setStyle(.inline)
        noteBtn.setTitle(Common.noteActionName(viewModel.transaction?.memo ?? ""), for: .normal)
        noteBtn.addTarget(self, action: #selector(noteBtnTapped), for: .touchUpInside)
        if !viewModel.enableExportPsbt() {
            navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: noteBtn)]
        }
    }

    @objc func noteBtnTapped(_ sender: Any) {
        presentDialogEditViewController()
    }

    func presentDialogEditViewController() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogEditViewController") as? DialogEditViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.prefill = viewModel.transaction?.memo ?? ""
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func presentSendSuccessViewController(_ result: SendTransactionSuccess) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendSuccessViewController") as? SendSuccessViewController {
            vc.amount = viewModel.totalText
            vc.sendTransactionSuccess = result
            vc.delegate = self
            vc.isLightning = viewModel.isLightning
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func presentSendFailViewController(_ error: Error) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendFailViewController") as? SendFailViewController {
            vc.delegate = self
            vc.error = error
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func presentSendHWConfirmViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendHWConfirmViewController") as? SendHWConfirmViewController {
            vc.viewModel = viewModel.sendHWConfirmViewModel()
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func presentLTConfirmingViewController() {
        let ltFlow = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = ltFlow.instantiateViewController(withIdentifier: "LTConfirmingViewController") as? LTConfirmingViewController {
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func presentReEnable2faSuccessViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReEnable2faSuccessViewController") as? ReEnable2faSuccessViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    func presentQRPinUnlockFlow() {
        self.qrFlowNav.viewControllers = []
        let storyboard = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "QRUnlockJadeViewController") as? QRUnlockJadeViewController {
            vc.vm = QRUnlockJadeViewModel(scope: .oracle, testnet: viewModel.wm?.prominentNetwork.testnet ?? false)
            vc.requireSignerFlow = true
            vc.delegate = self
            self.qrFlowNav.viewControllers = [vc]
            self.qrFlowNav.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(self.qrFlowNav, animated: false, completion: nil)
        }
    }

    @MainActor
    func presentSignerFlow() {
        self.qrFlowNav.viewControllers = []
        let stb = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "QRPsbtShowViewController") as? QRPsbtShowViewController {
            vc.qrBcur = viewModel.bcurUnsignedPsbt
            vc.confirmModel = viewModel.sendHWConfirmViewModel()
            vc.delegate = self
            self.qrFlowNav.viewControllers = [vc]
            self.qrFlowNav.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(self.qrFlowNav, animated: false, completion: nil)
        }
    }

    func enterSignerFlow() {
        let stb = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "QRPsbtShowViewController") as? QRPsbtShowViewController {
            vc.qrBcur = viewModel.bcurUnsignedPsbt
            vc.confirmModel = viewModel.sendHWConfirmViewModel()
            vc.followsQRUnlock = true
            vc.delegate = self
            self.qrFlowNav.pushViewController(vc, animated: true)
        }
    }

    func widthdraw() {
        var desc = String(format: "id_you_are_redeeming_funds_from_s".localized, "\n\(viewModel.withdrawData?.domain ?? "")")
        if let description = viewModel.withdrawData?.defaultDescription {
            desc += description
        }
        startLoader(message: desc)
        Task {
            do {
                _ = try await viewModel.withdrawLnurl(desc: desc)
                stopLoader()
                presentAlertSuccess()
            } catch {
                stopLoader()
                squareSliderView.reset()
                DropAlert().error(message: error.description()?.localized ?? "id_operation_failure".localized)
            }
        }
    }

    func exportPsbt() {
        Task {
            do {
                try await viewModel.exportPsbt()
                presentQRUnlockSignDialogViewController()
            } catch {
                presentSendFailViewController(error)
            }
        }
    }

    @MainActor
    func send() {
        Task { [weak self] in
            await self?.send_()
        }
    }

    @MainActor
    func send_() async {
        if viewModel.isLightning {
            presentLTConfirmingViewController()
        } else if viewModel.hasHW && viewModel.signedPsbt == nil {
            presentSendHWConfirmViewController()
        } else {
            startLoader(message: "id_sending".localized)
        }
        let task = Task.detached {
            try await self.viewModel.send()
        }
        switch await task.result {
        case .success(let success):
            stopLoader()
            dismiss(animated: true, completion: {
                if self.viewModel.txType == .redepositExpiredUtxos {
                    self.presentReEnable2faSuccessViewController()
                } else {
                    self.presentSendSuccessViewController(success)
                }
            })
        case .failure(let err):
            squareSliderView.reset()
            dismiss(animated: true, completion: {
                self.presentSendFailViewController(err)
            })
        }
    }

    @MainActor
    func presentAlertSuccess() {
        let viewModel = AlertViewModel(title: "id_success".localized,
                                       hint: String(format: "id_s_will_send_you_the_funds_it".localized, viewModel.withdrawData?.domain ?? ""))
        let storyboard = UIStoryboard(name: "Alert", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as? AlertViewController {
            vc.viewModel = viewModel
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnInfoFee(_ sender: Any) {

        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendFeeInfoViewController") as? SendFeeInfoViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnSignViaQr(_ sender: Any) {
        exportPsbt()
    }
}

extension SendTxConfirmViewController: DialogEditViewControllerDelegate {

    func didSave(_ note: String) {
        viewModel.note = note
        reload()
    }

    func didClose() {
    }
}

extension SendTxConfirmViewController: SquareSliderViewDelegate {
    func sliderThumbIsMoving(_ sliderView: SquareSliderView) {
        //
    }

    func sliderThumbDidStopMoving(_ position: Int) {
        if position == 1 {
            if viewModel.isWithdraw {
                widthdraw()
            } else {
                if viewModel.needConnectHw() {
                    presentConnectViewController()
                } else if viewModel.needExportPsbt() {
                    exportPsbt()
                } else {
                    send()
                }
            }
        } else {
            if viewModel.enableExportPsbt() {
                viewModel.signedPsbt = nil
            }
        }
    }

    @MainActor
    func presentConnectViewController() {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogConnectViewController") as? HWDialogConnectViewController {
            vc.delegate = self
            vc.authentication = true
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
}
extension SendTxConfirmViewController: HWDialogConnectViewControllerDelegate {
    func connected() {
        // nothing
    }
    
    func logged() {
        send()
    }
    
    func cancel() {
        // nothing
    }
    
    func failure(err: Error) {
        onSupport(error: err)
    }
}

extension SendTxConfirmViewController: SendSuccessViewControllerDelegate, ReEnable2faSuccessViewControllerDelegate {
    func onDone() {
        StoreReviewHelper
            .shared
            .request(
                isSendAll: viewModel.sendAll,
                account: viewModel.wm?.account,
                walletItem: viewModel.subaccount)
        navigationController?.popToViewController(ofClass: WalletTabBarViewController.self)
    }

    func onShare() {
        if viewModel.isLightning {
            if let url = viewModel.sendTransaction?.url, let url = URL(string: url) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: { _ in self.onDone() })
                }
            }
        } else if viewModel.isLiquid {
            if let url = viewModel.urlForTxUnblinded() {
                let tx: [Any] = [url]
                let shareVC = UIActivityViewController(activityItems: tx, applicationActivities: nil)
                self.present(shareVC, animated: true, completion: { self.onDone() })
            }
        } else {
            if let url = viewModel.urlForTx() {
                let tx: [Any] = [url]
                let shareVC = UIActivityViewController(activityItems: tx, applicationActivities: nil)
                self.present(shareVC, animated: true, completion: { self.onDone() })
            }
        }
    }
}

extension SendTxConfirmViewController: SendFailViewControllerDelegate {
    func onAgain() {
        if viewModel.needConnectHw() {
            presentConnectViewController()
        } else if viewModel.needExportPsbt() {
            exportPsbt()
        } else {
            send()
        }
    }

    func onSupport(error: Error) {
        switch error {
        case TwoFactorCallError.cancel(_):
            break
        case TransactionError.failure(_, let paymentHash):
            presentDialogErrorViewController(error: error, paymentHash: paymentHash)
        default:
            presentDialogErrorViewController(error: error, paymentHash: nil)
        }
    }

    @MainActor
    func presentDialogErrorViewController(error: Error, paymentHash: String?) {
        let request = ZendeskErrorRequest(
            error: error.description()?.localized ?? "",
            network: viewModel.subaccount?.networkType ?? .bitcoinSS,
            paymentHash: paymentHash,
            shareLogs: true,
            screenName: "FailedTransaction")
        presentContactUsViewController(request: request)
    }
}
extension SendTxConfirmViewController: SendFeeInfoViewControllerDelegate {
    func didTapMore() {
        SafeNavigationManager.shared.navigate( ExternalUrls.feesInfo )
    }
}

extension SendTxConfirmViewController: AlertViewControllerDelegate {
    @MainActor
    func onAlertOk() {
        navigationController?.popToViewController(ofClass: WalletTabBarViewController.self)
    }
}
extension SendTxConfirmViewController: QRUnlockJadeViewControllerDelegate {
    func signerFlow() {
        enterSignerFlow()
    }

    @MainActor
    func login(credentials: gdk.Credentials) {
    }

    @MainActor
    func abort() {
        squareSliderView.reset()
    }

    @MainActor
    func signPsbt(_ psbt: String) {
        viewModel.signedPsbt = psbt
        send()
    }
}

extension SendTxConfirmViewController: QRUnlockSignDialogViewControllerDelegate {
    @MainActor
    func onTap(_ action: QRUnlockSignDialogAction) {
        switch action {
        case .cancel:
            break
        case .connect:
            break
        case .unlocked:
            presentSignerFlow()
        case .unlock:
            presentQRPinUnlockFlow()
//        case .copy:
//            if let psbt = viewModel.unsignedPsbt {
//                UIPasteboard.general.string = psbt
//                DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 2.0)
//            }
        }
        squareSliderView.reset()
    }

    @MainActor
    func presentQRUnlockSignDialogViewController() {
        let stb = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "QRUnlockSignDialogViewController") as? QRUnlockSignDialogViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
}
extension SendTxConfirmViewController: QRPsbtShowViewControllerDelegate {
    @MainActor
    func close() {
        squareSliderView.reset()
    }

    @MainActor
    func next() {
        presentDialogScanViewController()
    }
}

extension SendTxConfirmViewController: QRPsbtAquireViewControllerDelegate {
    @MainActor
    func didScan(value: ScanResult, index: Int?) {
        if let psbt = value.bcur?.psbt {
            viewModel.signedPsbt = psbt
            send()
        } else {
            DropAlert().error(message: "Invalid psbt")
        }
        UIApplication.shared.delegate?.window??.rootViewController?.dismiss(animated: true)
    }

    @MainActor
    func didStop() {
        squareSliderView.reset()
        UIApplication.shared.delegate?.window??.rootViewController?.dismiss(animated: true)
    }

    @MainActor
    func presentDialogScanViewController() {
        let storyboard = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "QRPsbtAquireViewController") as? QRPsbtAquireViewController {
            vc.delegate = self
            self.qrFlowNav.pushViewController(vc, animated: true)
        }
    }
}
