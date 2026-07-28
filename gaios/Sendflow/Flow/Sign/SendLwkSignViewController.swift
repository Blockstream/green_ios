import Foundation
import UIKit
import core

import greenaddress
import lightning

class SendLwkSignViewController: UIViewController {

    @IBOutlet weak var cardAssetFrom: UIView!
    @IBOutlet weak var iconAssetFrom: UIImageView!
    @IBOutlet weak var lblToAssetTitleFrom: UILabel!
    @IBOutlet weak var lblAssetNameFrom: UILabel!
    @IBOutlet weak var lblAccountNameFrom: UILabel!

    @IBOutlet weak var assetToStackView: UIStackView!
    @IBOutlet weak var cardAssetTo: UIView!
    @IBOutlet weak var iconAssetTo: UIImageView!
    @IBOutlet weak var lblToAssetTitleTo: UILabel!
    @IBOutlet weak var lblAssetNameTo: UILabel!
    @IBOutlet weak var lblAccountNameTo: UILabel!

    @IBOutlet weak var addressStackView: UIStackView!
    @IBOutlet weak var addressCard: UIView!
    @IBOutlet weak var lblAddressTitle: UILabel!
    @IBOutlet weak var addressTextView: UITextView!
    
    @IBOutlet weak var amountCard: UIView!
    @IBOutlet weak var lblAmountTitle: UILabel!
    @IBOutlet weak var lblAmountValue: UILabel!
    @IBOutlet weak var lblAmountFiat: UILabel!
    @IBOutlet weak var lblAmountSubtitle: UILabel!
    
    @IBOutlet weak var noteView: UIStackView!
    @IBOutlet weak var lblNoteTitle: UILabel!
    @IBOutlet weak var lblNoteTxt: UILabel!
    @IBOutlet weak var notesCard: UIView!

    @IBOutlet weak var lblSumFeeKey: UILabel!
    @IBOutlet weak var btnInfoFee: UIButton!
    @IBOutlet weak var lblSumFeeValue: UILabel!
    @IBOutlet weak var lblSumAmountKey: UILabel!
    @IBOutlet weak var lblSumAmountValue: UILabel!
    @IBOutlet weak var lblSumAmountView: UIView!
    @IBOutlet weak var lblSumTotalKey: UILabel!
    @IBOutlet weak var lblSumTotalValue: UILabel!
    @IBOutlet weak var totalsView: UIStackView!
    @IBOutlet weak var lblConversion: UILabel!
    @IBOutlet weak var squareSliderView: SquareSliderView!

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
        if viewModel.isNoteEditable {
            addNoteInNavigation()
        }
        reload()
        
        btnInfoFee.accessibilityIdentifier = AccessibilityIds.SendConfirmScreen.btnInfoFee
        btnInfoFee.isAccessibilityElement = true
    }

    func setContent() {
        title = "id_confirm_transaction".localized
        lblToAssetTitleTo.text = "id_to".localized.capitalized
        lblAmountFiat.text = ""
        lblAssetNameFrom.text = ""
        lblAssetNameTo.text = ""
        lblAccountNameFrom.text = ""
        lblAccountNameTo.text = ""
        lblAddressTitle.text = "id_recipient".localized.capitalized
        lblAmountTitle.text = "id_amount".localized.capitalized
        lblAmountValue.text = ""
        lblSumFeeKey.text = "Total Fees".localized
        lblSumFeeValue.text = ""
        lblSumAmountKey.text = "id_amount".localized
        lblSumAmountValue.text = ""
        lblSumTotalKey.text = "id_total_spent".localized
        lblSumTotalValue.text = ""
        lblNoteTitle.text = "id_note".localized
        lblNoteTxt.text = ""
        squareSliderView.isHidden = false
        lblAmountSubtitle.isHidden = viewModel.submarineSubtitle == nil
        lblAmountSubtitle.text = viewModel.submarineSubtitle?.localized
    }

    func setStyle() {
        [cardAssetFrom, cardAssetTo, addressCard, amountCard, notesCard].forEach {
            $0?.cornerRadius = 4.0
            $0?.setStyle(CardStyle.defaultStyle)
        }
        [lblToAssetTitleFrom, lblToAssetTitleTo, lblAddressTitle, lblAmountTitle, lblNoteTitle].forEach {
            $0?.setStyle(.txtSectionHeader)
        }
        [lblAccountNameFrom, lblAccountNameTo].forEach {
            $0.setStyle(.txtSmaller)
            $0.textColor = .gGrayTxt()
        }
        [lblSumFeeKey, lblSumFeeValue, lblSumAmountKey, lblSumAmountValue, lblNoteTxt, lblConversion, lblAmountFiat].forEach {
            $0?.setStyle(.txtCard)
        }
        [lblSumTotalKey, lblSumTotalValue].forEach {
            $0.setStyle(.txt)
            $0.font = UIFont.systemFont(ofSize: $0.font.pointSize, weight: .semibold)
        }
        [lblAssetNameFrom, lblAssetNameTo].forEach {
            $0?.setStyle(.titleCard)
        }
        lblAmountValue.font = UIFont.systemFont(ofSize: 28.0, weight: .medium)
        lblAmountValue.textColor = .white
        lblAmountSubtitle.setStyle(.txtSmaller)
        lblAmountSubtitle.textColor = .gGrayTxt()
        btnInfoFee.setImage(UIImage(named: "ic_lightning_info_err")!.maskWithColor(color: UIColor.gW40()), for: .normal)
    }

    func addNoteInNavigation() {
        let noteBtn = UIButton(type: .system)
        noteBtn.setStyle(.inline)
        noteBtn
            .setTitle(
                Common.noteActionName(viewModel.tx.memo ?? ""),
                for: .normal
            )
        noteBtn.addTarget(self, action: #selector(noteBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: noteBtn)]
    }

    func reloadLightningPayment() {
        lblToAssetTitleFrom.text = "id_asset".localized
        cardAssetFrom.isHidden = false
        assetToStackView.isHidden = true
        addressStackView.isHidden = false
        lblAssetNameFrom.text = viewModel.assetFrom?.name ?? viewModel.assetIdFrom
        iconAssetFrom.image = viewModel.assetImageFrom
        lblAccountNameFrom.isHidden = true
        totalsView.isHidden = true
        lblConversion.isHidden = true
        lblAmountSubtitle.isHidden = true
        lblAmountValue.text = convertToDenom(viewModel.invoiceSatoshi ?? 0)
        lblAmountFiat.text = "≈ \(convertToFiat(viewModel.invoiceSatoshi ?? 0) ?? "")"
        if let recipient = viewModel.recipientAddress {
            AddressDisplay.configure(
                address: recipient,
                textView: addressTextView,
                style: .yellow,
                truncate: true)
        }
        noteView.isHidden = viewModel.isNoteHidden
        lblNoteTxt.text = viewModel.note
    }
    func reloadInternalSwap() {
        lblToAssetTitleFrom.text = "From".localized
        lblAmountValue.text = convertToDenom(viewModel.recipientSatoshi ?? 0)
        lblAmountFiat.text = "≈ \(convertToFiat(viewModel.recipientSatoshi ?? 0) ?? "")"
        lblSumAmountKey.text = "id_total_spent".localized
        lblSumTotalKey.text = "Total to Receive".localized
        cardAssetFrom.isHidden = false
        assetToStackView.isHidden = false
        addressStackView.isHidden = true
        lblAssetNameFrom.text = viewModel.assetFrom?.name ?? viewModel.assetIdFrom
        lblAssetNameTo.text = viewModel.assetTo?.name ?? viewModel.assetIdTo
        iconAssetFrom.image = viewModel.assetImageFrom
        iconAssetTo.image = viewModel.assetImageTo
        
        lblAccountNameFrom.text = viewModel.subaccountFrom.localizedName.uppercased()
        lblAccountNameFrom.isHidden = !viewModel.hasMultipleSubaccounts(for: viewModel.subaccountFrom)
        if let toAccount = viewModel.subaccountTo {
            lblAccountNameTo.text = toAccount.localizedName.uppercased()
            lblAccountNameTo.isHidden = !viewModel.hasMultipleSubaccounts(for: toAccount)
        } else {
            lblAccountNameTo.isHidden = true
        }
        lblSumAmountValue.text = convertToDenom(viewModel.satoshiWithFee ?? 0)
        lblSumFeeValue.text = viewModel.convertFeeToDenom(satoshi: viewModel.totalFee ?? 0)
        lblSumTotalValue.text = convertToDenom(viewModel.recipientSatoshi ?? 0)
        lblConversion.text = "≈ \(convertToFiat(viewModel.recipientSatoshi ?? 0) ?? "")"
        lblSumAmountView.isHidden = false
        lblAmountSubtitle.isHidden = true
        totalsView.isHidden = false
        noteView.isHidden = viewModel.isNoteHidden
        lblNoteTxt.text = viewModel.note
    }
    func convertToDenom(_ satoshi: UInt64) -> String? {
        return viewModel.convertToDenom(satoshi: satoshi)
    }
    func convertToFiat(_ satoshi: UInt64) -> String? {
        return viewModel.convertToFiat(satoshi: satoshi)
    }
    func reloadSubmarineSwap() {
        lblToAssetTitleFrom.text = "id_asset".localized
        lblAmountValue.text = convertToDenom(viewModel.recipientSatoshi ?? 0)
        lblAmountFiat.text = "≈ \(convertToFiat(viewModel.recipientSatoshi ?? 0) ?? "")"
        cardAssetFrom.isHidden = false
        assetToStackView.isHidden = true
        addressStackView.isHidden = false
        lblAssetNameFrom.text = viewModel.assetFrom?.name ?? viewModel.assetIdFrom
        iconAssetFrom.image = viewModel.assetImageFrom
        lblAccountNameFrom.isHidden = true
        lblSumFeeValue.text = viewModel.convertFeeToDenom(satoshi: viewModel.totalFee ?? 0)
        lblSumAmountValue.text = convertToDenom(viewModel.recipientSatoshi ?? 0)
        lblSumTotalValue.text = convertToDenom(viewModel.satoshiWithFee ?? 0)
        lblConversion.text = "≈ \(convertToFiat(viewModel.satoshiWithFee ?? 0) ?? "")"
        lblSumAmountView.isHidden = true
        lblAmountSubtitle.isHidden = false
        totalsView.isHidden = false
        if let recipient = viewModel.recipientAddress {
            AddressDisplay.configure(
                address: recipient,
                textView: addressTextView,
                style: .yellow,
                truncate: true)
        }
        noteView.isHidden = viewModel.isNoteHidden
        lblNoteTxt.text = viewModel.note
    }
    func reload() {
        if viewModel.isInternalSwap || viewModel.isCrossChainSwap {
            reloadInternalSwap()
        } else if viewModel.usesLightningRail {
            reloadLightningPayment()
        } else {
            reloadSubmarineSwap()
        }
    }
    func networkImage(_ network: NetworkId) -> UIImage? {
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
            networkFee: viewModel.convertFeeToDenom(satoshi: viewModel.networkFee ?? 0) ?? "",
            lightningSetupFee: viewModel.lightningSetupFee != nil ? viewModel.convertFeeToDenom(satoshi: viewModel.lightningSetupFee ?? 0) : nil,
            swapFee: viewModel.convertFeeToDenom(satoshi: viewModel.swapFee ?? 0) ?? "",
            total: viewModel.convertFeeToDenom(satoshi: viewModel.totalFee ?? 0) ?? "",
            fiat: "≈ " + (viewModel.convertFeeToFiat(satoshi: viewModel.totalFee ?? 0) ?? ""))
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

    @objc func noteBtnTapped(_ sender: Any) {
        if let vc = dialogEditViewController() {
            present(vc, animated: false, completion: nil)
        }
    }

    func dialogEditViewController() -> DialogEditViewController? {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogEditViewController") { coder in
            DialogEditViewController(coder: coder, prefill: self.viewModel.tx.memo ?? "")
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.delegate = self
        return vc
    }

    func send() {
        if viewModel.mainWallet.isHW && viewModel.draft.subaccount?.isLightning == false {
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

extension SendLwkSignViewController: DialogEditViewControllerDelegate {

    func didSave(_ note: String) {
        viewModel.tx.memo = note
        reload()
    }

    func didClose() {
    }
}
