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

    var viewModel: SendTxConfirmViewModel!
    weak var verifyOnDeviceViewController: VerifyOnDeviceViewController?

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
    }

    func setStyle() {
        [assetCard, addressCard, amountCard, notesCard, payRequestByCard].forEach {
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
    }

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

    @IBAction func btnVerifyAddress(_ sender: Any) {
        if let vm = viewModel.sendVerifyOnDeviceViewModel() {
            presentVerifyOnDeviceViewController(viewModel: vm)
        }
        Task {
            do {
                let res = try await viewModel.validateHW()
                await MainActor.run {
                    verifyOnDeviceViewController?.dismiss()
                    if res {
                        viewModel.verifyAddressState = .verified
                        updateVerifyAddressState()
                        DropAlert().success(message: "id_the_address_is_valid".localized)
                    } else {
                        DropAlert().error(message: "id_the_addresses_dont_match".localized)
                    }
                }
            } catch {
                verifyOnDeviceViewController?.dismiss()
                DropAlert().error(message: error.description()?.localized ?? "")
            }
        }
    }

    @MainActor
    func presentVerifyOnDeviceViewController(viewModel: VerifyOnDeviceViewModel) {
        let storyboard = UIStoryboard(name: "VerifyOnDevice", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "VerifyOnDeviceViewController") as? VerifyOnDeviceViewController {
            vc.viewModel = viewModel
            verifyOnDeviceViewController = vc
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
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

    func updateNavigationItem() {
        let noteBtn = UIButton(type: .system)
        noteBtn.setStyle(.inline)
        noteBtn.setTitle(Common.noteActionName(viewModel.transaction?.memo ?? ""), for: .normal)
        noteBtn.addTarget(self, action: #selector(noteBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: noteBtn)]
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

    func send() {
        Task {
            do {
                startLoader(message: "id_sending".localized)
                if viewModel.isLightning {
                    presentLTConfirmingViewController()
                } else if viewModel.hasHW {
                    presentSendHWConfirmViewController()
                }
                let res = try await self.viewModel.send()
                stopLoader()
                await MainActor.run {
                    dismiss(animated: true, completion: {
                        if self.viewModel.txType == .redepositExpiredUtxos {
                            self.presentReEnable2faSuccessViewController()
                        } else {
                            self.presentSendSuccessViewController(res)
                        }
                    })
                }
            } catch {
                stopLoader()
                await MainActor.run {
                    squareSliderView.reset()
                    dismiss(animated: true, completion: {
                        self.presentSendFailViewController(error)
                    })
                }
            }
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
                send()
            }
        }
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
        popViewController()
    }

    func popViewController() {
        let avc = navigationController?.viewControllers.filter { $0 is AccountViewController }.first
        if avc != nil {
            navigationController?.popToViewController(ofClass: AccountViewController.self)
        } else {
            navigationController?.popToViewController(ofClass: WalletViewController.self)
        }
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
        send()
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
        let request = DialogErrorRequest(
            account: AccountsRepository.shared.current,
            networkType: viewModel.subaccount?.networkType ?? .bitcoinSS,
            error: error.description()?.localized ?? "",
            screenName: "FailedTransaction",
            paymentHash: paymentHash)
        if AppSettings.shared.gdkSettings?.tor ?? false {
            self.showOpenSupportUrl(request)
            return
        }
        if let vc = UIStoryboard(name: "Dialogs", bundle: nil)
            .instantiateViewController(withIdentifier: "DialogErrorViewController") as? DialogErrorViewController {
            vc.request = request
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
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
        let avc = navigationController?.viewControllers.filter { $0 is AccountViewController }.first
        if avc != nil {
            navigationController?.popToViewController(ofClass: AccountViewController.self)
        } else {
            navigationController?.popToViewController(ofClass: WalletViewController.self)
        }
    }
}
