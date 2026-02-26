import Foundation
import UIKit
import core
import gdk
import greenaddress
import BreezSDK
import lightning

class SendLwkSignViewController: UIViewController {

    @IBOutlet weak var addressCard: UIView!
    @IBOutlet weak var amountCard: UIView!
    @IBOutlet weak var notesCard: UIView!
    @IBOutlet weak var cardAssetFrom: UIView!
    @IBOutlet weak var iconAssetFrom: UIImageView!
    @IBOutlet weak var lblToAssetTitleFrom: UILabel!
    @IBOutlet weak var lblAssetNameFrom: UILabel!
    @IBOutlet weak var lblAccount1From: UILabel!

    @IBOutlet weak var cardAssetTo: UIView!
    @IBOutlet weak var iconAssetTo: UIImageView!
    @IBOutlet weak var lblToAssetTitleTo: UILabel!
    @IBOutlet weak var lblAssetNameTo: UILabel!
    @IBOutlet weak var lblAccount1To: UILabel!
    @IBOutlet weak var lblAddressTitle: UILabel!

    @IBOutlet weak var lblAmountTitle: UILabel!
    @IBOutlet weak var addressTextView: UITextView!
    @IBOutlet weak var lblAmountValue: UILabel!
    @IBOutlet weak var lblAmountFiat: UILabel!
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

    var viewModel: SendLwkSignViewModel!

    init?(coder: NSCoder, viewModel: SendLwkSignViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        squareSliderView.delegate = self
        setContent()
        setStyle()
        reload()
    }

    func setContent() {
        title = "id_review".localized
        lblToAssetTitleFrom.text = "id_from".localized.capitalized
        lblToAssetTitleTo.text = "id_to".localized.capitalized
        lblAmountFiat.text = ""
        lblAssetNameFrom.text = ""
        lblAccount1From.text = ""
        lblAssetNameTo.text = ""
        lblAccount1To.text = ""
        lblAddressTitle.text = "id_send_to".localized.capitalized
        lblAmountTitle.text = "id_amount".localized.capitalized
        lblAmountValue.text = ""
        lblSumFeeKey.text = "Total fees".localized
        lblSumFeeValue.text = ""
        lblSumAmountKey.text = "id_amount".localized
        lblSumAmountValue.text = ""
        lblSumTotalKey.text = "id_total_spent".localized
        lblSumTotalValue.text = ""
        lblNoteTitle.text = "id_my_notes".localized
        lblNoteTxt.text = ""
        squareSliderView.isHidden = false
        lblAmountSubtitle.isHidden = viewModel.isCrossChainSwap
        lblAmountSubtitle.text = "You are paying this Lightning invoice with Liquid bitcoin".localized
    }

    func setStyle() {
        lblAmountValue.setStyle(.title)
        [cardAssetFrom, cardAssetTo, addressCard, amountCard, notesCard].forEach {
            $0?.cornerRadius = 4.0
        }
        [lblToAssetTitleFrom, lblToAssetTitleTo, lblAddressTitle, lblAmountTitle, lblNoteTitle].forEach {
            $0?.setStyle(.sectionTitle)
        }
        [lblSumFeeKey, lblSumFeeValue, lblSumAmountKey, lblSumAmountValue, lblNoteTxt, lblConversion, lblAccount1From, lblAccount1To, lblAmountFiat].forEach {
            $0?.setStyle(.txtCard)
        }
        [lblSumTotalKey, lblSumTotalValue, lblAssetNameFrom, lblAssetNameTo].forEach {
            $0?.setStyle(.txtBigger)
        }
        lblAmountSubtitle.setStyle(.txt)
        btnInfoFee.setImage(UIImage(named: "ic_lightning_info_err")!.maskWithColor(color: UIColor.gW40()), for: .normal)
    }

    func reloadCrossChainSwap() {
        lblAmountValue.text = convertToDenom(viewModel.recipientSatoshi ?? 0)
        lblAmountFiat.text = "≈ \(convertToFiat(viewModel.recipientSatoshi ?? 0) ?? "")"
        lblSumAmountKey.text = "id_total_spent".localized
        lblSumTotalKey.text = "Total to Receive".localized
        cardAssetFrom.isHidden = false
        cardAssetTo.isHidden = false
        lblToAssetTitleTo.isHidden = false
        addressCard.isHidden = true
        lblAddressTitle.isHidden = true
        lblAssetNameFrom.text = viewModel.assetFrom?.name ?? viewModel.assetIdFrom
        lblAssetNameTo.text = viewModel.assetTo?.name ?? viewModel.assetIdTo
        lblAccount1From.text = viewModel.subaccountFrom.localizedName.uppercased()
        lblAccount1To.text = viewModel.subaccountTo?.localizedName.uppercased() ?? ""
        iconAssetFrom.image = viewModel.assetImageFrom
        iconAssetTo.image = viewModel.assetImageTo
        lblSumAmountValue.text = convertToDenom(viewModel.satoshiWithFee ?? 0)
        lblSumFeeValue.text = convertToDenom(viewModel.totalFee ?? 0)
        lblSumTotalValue.text = convertToDenom(viewModel.recipientSatoshi ?? 0)
        lblConversion.text = "≈ \(convertToFiat(viewModel.recipientSatoshi ?? 0) ?? "")"
        lblSumAmountView.isHidden = false
        lblAmountSubtitle.isHidden = true
        totalsView.isHidden = false
        noteView.isHidden = true
    }
    func convertToDenom(_ satoshi: UInt64) -> String? {
        return viewModel.convertToDenom(satoshi: satoshi)
    }
    func convertToFiat(_ satoshi: UInt64) -> String? {
        return viewModel.convertToFiat(satoshi: satoshi)
    }
    func reloadSubmarineSwap() {
        lblAmountValue.text = convertToDenom(viewModel.recipientSatoshi ?? 0)
        lblAmountFiat.text = "≈ \(convertToFiat(viewModel.recipientSatoshi ?? 0) ?? "")"
        lblToAssetTitleTo.isHidden = true
        cardAssetFrom.isHidden = false
        cardAssetTo.isHidden = true
        addressCard.isHidden = false
        lblAddressTitle.isHidden = false
        lblAssetNameFrom.text = viewModel.assetFrom?.name ?? viewModel.assetIdFrom
        lblAccount1From.text = viewModel.subaccountFrom.localizedName.uppercased()
        iconAssetFrom.image = viewModel.assetImageFrom
        lblSumFeeValue.text = convertToDenom(viewModel.totalFee ?? 0)
        lblSumAmountValue.text = convertToDenom(viewModel.recipientSatoshi ?? 0)
        lblSumTotalValue.text = convertToDenom(viewModel.satoshiWithFee ?? 0)
        lblConversion.text = "≈ \(convertToFiat(viewModel.satoshiWithFee ?? 0) ?? "")"
        lblSumAmountView.isHidden = true
        lblAmountSubtitle.isHidden = false
        totalsView.isHidden = false
        lblNoteTxt.text = ""
        noteView.isHidden = true
        if let bolt11 = try? viewModel.bolt11 {
            lblNoteTxt.text = bolt11.invoiceDescription()
            noteView.isHidden = bolt11.invoiceDescription().isEmpty
            AddressDisplay.configure(
                address: bolt11.description,
                textView: addressTextView,
                style: .default,
                truncate: true)
        }
    }
    func reload() {
        if viewModel.isCrossChainSwap {
            reloadCrossChainSwap()
        } else {
            reloadSubmarineSwap()
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

    @IBAction func btnInfoFee(_ sender: Any) {
        let vc = sendFeeInfoViewController()
        present(vc, animated: true)
    }

    func sendFeeInfoViewController() -> SendFeeInfoViewController {
        let scope = SendFeeScope.lwkSwap(
            networkFee: convertToDenom(viewModel.networkFee ?? 0) ?? "",
            providerFee: convertToDenom(viewModel.providerFee ?? 0) ?? "",
            total: convertToDenom(viewModel.totalFee ?? 0) ?? "",
            fiat: "≈ " + (convertToFiat(viewModel.totalFee ?? 0) ?? ""))
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        // swiftlint:disable:next force_cast
        let vc = storyboard.instantiateViewController(withIdentifier: "SendFeeInfoViewController") as! SendFeeInfoViewController
        vc.delegate = self
        vc.scope = scope
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }

    func hWDialogConnectViewController() -> HWDialogConnectViewController {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        // swiftlint:disable:next force_cast
        let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogConnectViewController") as! HWDialogConnectViewController
        vc.delegate = self
        vc.authentication = true
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }

    func send() {
        let account = AccountsRepository.shared.current
        if account?.isJade ?? false {
            if !BleHwManager.shared.isConnected() || !BleHwManager.shared.isLogged() {
                let vc = hWDialogConnectViewController()
                present(vc, animated: true)
                return
            }
        }
        Task { [weak self] in
            await self?.viewModel.send()
        }
    }
}

extension SendLwkSignViewController: HWDialogConnectViewControllerDelegate {
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
        showError(err.description().localized)
    }
}
extension SendLwkSignViewController: SquareSliderViewDelegate {
    func sliderThumbIsMoving(_ sliderView: SquareSliderView) {
        //
    }

    func sliderThumbDidStopMoving(_ position: Int) {
        if position == 1 {
            send()
        }
    }

}

extension SendLwkSignViewController: SendFeeInfoViewControllerDelegate {
    func didTapMore() {
        SafeNavigationManager.shared.navigate( ExternalUrls.swapFeeSectionDialog )
    }
}

extension SendLwkSignViewController: SendFlowErrorDisplayable {
    func handleSendFlowError(_ error: Error?) {
        squareSliderView.reset()
        if let error {
            showError(error.description().localized)
        }
    }
}
