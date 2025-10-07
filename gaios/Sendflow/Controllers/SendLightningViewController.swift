import Foundation
import UIKit
import core
import gdk
import greenaddress
import BreezSDK
import lightning

class SendLightningViewController: UIViewController {

    @IBOutlet weak var assetCard: UIView!
    @IBOutlet weak var addressCard: UIView!
    @IBOutlet weak var amountCard: UIView!
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
    @IBOutlet weak var lblAmountSubtitle: UILabel!

    @IBOutlet weak var noteView: UIStackView!
    @IBOutlet weak var lblNoteTitle: UILabel!
    @IBOutlet weak var lblNoteTxt: UILabel!
    @IBOutlet weak var btnInfoFee: UIButton!

    let qrFlowNav = UINavigationController()
    private let iconW: CGFloat = 36.0

    var viewModel: SendLightningViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        squareSliderView.delegate = self
        setContent()
        setStyle()
        reload()
    }

    func setContent() {
        lblAssetTitle.text = "id_account__asset".localized
        lblAddressTitle.text = viewModel.addressTitle.localized
        lblAmountTitle.text = viewModel.amountTitle.localized
        lblAmountValue.text = ""
        lblAmountFee.text = ""
        lblAssetName.text = ""
        lblAccount1.text = ""
        lblAccount2.text = ""
        lblSumFeeKey.text = "Total fees".localized
        lblSumFeeValue.text = ""
        lblSumAmountKey.text = "id_recipient_receives".localized
        lblSumAmountValue.text = ""
        lblSumTotalKey.text = "id_total_spent".localized
        lblSumTotalValue.text = ""
        lblNoteTitle.text = "id_my_notes".localized
        lblNoteTxt.text = ""
        squareSliderView.isHidden = false
        lblAmountSubtitle.text = "You are paying this Lightning invoice with Liquid bitcoin"
    }

    func setStyle() {
        [assetCard, addressCard, amountCard, notesCard].forEach {
            $0?.cornerRadius = 4.0
        }
        [lblAssetTitle, lblAddressTitle, lblAmountTitle, lblNoteTitle].forEach {
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
        lblAmountSubtitle.setStyle(.txt)
        btnInfoFee.setImage(UIImage(named: "ic_lightning_info_err")!.maskWithColor(color: UIColor.gW40()), for: .normal)
    }

    func reload() {
        lblAmountValue.text = viewModel.recipientAmountText
        lblAmountFee.text = "≈ \(viewModel.recipientSubamountText ?? "")"
        lblAssetName.text = viewModel.asset?.name ?? viewModel.assetId
        lblAccount1.text = viewModel.liquidAccount.localizedName.uppercased()
        lblAccount2.text = viewModel.liquidAccount.type.shortText.uppercased()
        iconAsset.image = viewModel.assetImage
        iconType.image = networkImage(viewModel.liquidAccount.networkType)

        lblSumFeeValue.text = viewModel.totalFeeText
        lblSumAmountValue.text = viewModel.recipientAmountText
        lblSumTotalValue.text = viewModel.totalText
        lblConversion.text = "≈ \(viewModel?.conversionText ?? "")"
        lblNoteTxt.text = viewModel.invoice.invoiceDescription()
        totalsView.isHidden = false
        noteView.isHidden = viewModel.invoice.invoiceDescription().isEmpty
        noteView.isHidden = viewModel.invoice.invoiceDescription().isEmpty
        lblSumAmountView.isHidden = false
        lblAmountSubtitle.isHidden = false

        AddressDisplay.configure(
            address: viewModel.invoice.description,
                textView: addressTextView,
                style: .default,
                truncate: true)
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

    @MainActor
    func presentSendSuccessViewController(_ result: SendTransactionSuccess) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendSuccessViewController") as? SendSuccessViewController {
            vc.amount = viewModel.totalText
            vc.sendTransactionSuccess = result
            vc.delegate = self
            vc.isLightning = true
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func waitingSwapCompletion() async {
        guard let pay = viewModel.swapPayResponse else { return }
        let res = Task.detached(priority: .background) { [weak self] in
            try await self?.viewModel.lwk.handlePay(pay: pay)
        }
        switch await res.result {
        case .success:
            logger.info("BOLTZ payment done")
            //LocalNotification().show(title: "Payment success", subtitle: "")
        case .failure(let err):
            logger.error("BOLTZ payment error: \(err.description().localized, privacy: .public)")
            //LocalNotification().show(title: "Payment Failure", subtitle: err.description().localized)
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
    func send() async {
        startLoader(message: "id_sending".localized)
        let task = Task.detached {
            try await self.viewModel.send()
        }
        switch await task.result {
        case .success:
            stopLoader()
            Task.detached { [weak self] in await self?.waitingSwapCompletion() }
            dismiss(animated: true, completion: {
                if let sendSuccess = self.viewModel.sendTransaction {
                    self.presentSendSuccessViewController(sendSuccess)
                }
            })
        case .failure(let err):
            stopLoader()
            squareSliderView.reset()
            dismiss(animated: true, completion: {
                self.presentSendFailViewController(err)
            })
        }
    }

    @IBAction func btnInfoFee(_ sender: Any) {
        let scope = SendFeeScope.lwkSwap(
            swap: viewModel.swapFee?.toText() ?? "",
            chain: viewModel.txFee?.toText() ?? "",
            total: viewModel.totalFee?.toText() ?? "",
            fiat: viewModel.totalFeeFiatText ?? "")
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendFeeInfoViewController") as? SendFeeInfoViewController {
            vc.delegate = self
            vc.scope = scope
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
}

extension SendLightningViewController: SquareSliderViewDelegate {
    func sliderThumbIsMoving(_ sliderView: SquareSliderView) {
        //
    }

    func sliderThumbDidStopMoving(_ position: Int) {
        if position == 1 {
            Task { [weak self] in
                await self?.send()
            }
        }
    }

}
extension SendLightningViewController: SendSuccessViewControllerDelegate {
    func onDone() {
        StoreReviewHelper
            .shared
            .request(
                isSendAll: viewModel.sendAll,
                account: AccountsRepository.shared.current,
                walletItem: viewModel.liquidAccount)
        navigationController?.popToViewController(ofClass: WalletTabBarViewController.self)
    }

    func onShare() {
        if let url = viewModel.urlForTxUnblinded() {
            let tx: [Any] = [url]
            let shareVC = UIActivityViewController(activityItems: tx, applicationActivities: nil)
            self.present(shareVC, animated: true, completion: { self.onDone() })
        }
    }
}

extension SendLightningViewController: SendFailViewControllerDelegate {
    func onAgain() {
        Task { [weak self] in
            await self?.send()
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
            error: error.description().localized,
            network: viewModel.liquidAccount.networkType,
            paymentHash: paymentHash,
            shareLogs: true,
            screenName: "FailedTransaction")
        presentContactUsViewController(request: request)
    }
}
extension SendLightningViewController: SendFeeInfoViewControllerDelegate {
    func didTapMore() {
        SafeNavigationManager.shared.navigate( ExternalUrls.feesInfo )
    }
}
