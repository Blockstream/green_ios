import Foundation
import UIKit
import core
import gdk

class LNInvoiceViewController: UIViewController {

    @IBOutlet weak var bgCard: UIView!
    @IBOutlet weak var bgCardQR: UIView!
    @IBOutlet weak var envelopeView: UIView!
    @IBOutlet weak var envelopeBorderView: UIView!
    @IBOutlet weak var btnQRCode: UIButton!
    @IBOutlet weak var qrFrame: QRCodeView!
    @IBOutlet weak var btnMagnify: UIButton!
    @IBOutlet weak var btnCopyAddress: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var plainTxt: UILabel!
    @IBOutlet weak var groupedTxt: UITextView!
    @IBOutlet weak var lblExpire: UILabel!
    @IBOutlet weak var btnShare: UIButton!

    @IBOutlet weak var lblNoteTitle: UILabel!
    @IBOutlet weak var lblNoteValue: UILabel!
    @IBOutlet weak var totalsStack: UIStackView!
    @IBOutlet weak var fundView: UIView!
    @IBOutlet weak var lblFundFeeKey: UILabel!
    @IBOutlet weak var lblFundFeeValue: UILabel!
    @IBOutlet weak var lblFundFeeFiat: UILabel!
    @IBOutlet weak var lblAmountKey: UILabel!
    @IBOutlet weak var lblAmountValue: UILabel!
    @IBOutlet weak var lblAmountFiat: UILabel!
    @IBOutlet weak var btnFundFee: UIButton!
    @IBOutlet weak var noteView: UIView!
    private var invoiceObservationTask: Task<Void, Never>?
    private var handledPaidInvoice = false
    var viewModel: LNInvoiceViewModel!

    init?(coder: NSCoder, viewModel: LNInvoiceViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Lightning Invoice".localized
        setContent()
        setStyle()

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        qrFrame.addGestureRecognizer(longPressRecognizer)
        Task {
            await self.generateInvoice()
        }
        [lblNoteTitle, noteView].forEach {
            $0?.isHidden = true
        }
        viewModel.onInvoicePaid = {
            DropAlert().success(message: "id_payment_received".localized)
        }
        viewModel.listenToEvents()
    }

    deinit {
        invoiceObservationTask?.cancel()
    }
    func setContent() {
        plainTxt.isHidden = true
        groupedTxt.isHidden = true
        btnShare.setTitle("id_share".localized, for: .normal)
        [btnShare, btnMagnify, btnCopyAddress, btnQRCode].forEach {
            $0.isHidden = true
        }
        lblExpire.text = ""
        totalsStack.isHidden = true
        lblFundFeeKey.text = "Funding Fee".localized
        lblAmountKey.text = "Amount to Receive".localized
        totalsStack.isHidden = true
    }
    func setStyle() {
        envelopeBorderView.backgroundColor = .clear
        envelopeBorderView.borderWidth = 8.0
        envelopeBorderView.borderColor = UIColor.gLightning()
        envelopeBorderView.cornerRadius = 25.0
        btnMagnify.setTitle("Enlarge QR".localized, for: .normal)
        btnMagnify.setImage(UIImage(named: "ic_magnify_qr")?.maskWithColor(color: UIColor.gAccent()), for: .normal)
        switch viewModel.type {
        case .bolt11, .lwkSwap:
            btnCopyAddress.setTitle("Copy Invoice".localized, for: .normal)
        default:
            btnCopyAddress.setTitle("id_copy_address".localized, for: .normal)
        }
        btnCopyAddress.setImage(UIImage(named: "ic_copy_receve")?.maskWithColor(color: UIColor.gAccent()), for: .normal)
        [btnMagnify, btnCopyAddress].forEach {
            $0.setStyle(.accentWithImg)
        }
        plainTxt.lineBreakMode = .byTruncatingTail
        btnShare.setStyle(.primary)
        lblExpire.setStyle(.txtCard)
        [lblFundFeeKey, lblFundFeeValue, lblFundFeeFiat, lblAmountFiat, lblNoteValue, lblNoteTitle].forEach {
            $0?.setStyle(.txtCard)
        }
        [lblAmountKey, lblAmountValue].forEach {
            $0?.setStyle(.txtBigger)
        }
        if let fundFeeImage = UIImage(named: "ic_lightning_info_err") {
            btnFundFee.setImage(fundFeeImage.maskWithColor(color: UIColor.gW40()), for: .normal)
        }
        noteView.setStyle(CardStyle.defaultStyle)
    }

    func generateInvoice() async {
        let task = Task.detached(priority: .background) { [weak self] in
            try await self?.viewModel?.newAddress()
        }
        switch await task.result {
        case .success:
            groupedTxt.isHidden = false
            AddressDisplay.configure(
                address: viewModel.bolt11 ?? "",
                textView: groupedTxt,
                style: .yellow,
                truncate: true)
            qrFrame.backgroundColor = .clear
            qrFrame.cornerRadius = 12.0
            btnShare.isHidden = false
            if let uri = viewModel.bolt11, !uri.isEmpty {
                qrFrame.isHidden = false
                qrFrame.configure(frames: [uri])
            } else {
                qrFrame.stopAnimation()
                qrFrame.isHidden = true
            }
            [btnShare, btnMagnify, btnCopyAddress, btnQRCode].forEach {
                $0.isHidden = false
            }
            totalsStack.isHidden = false
            lblExpire.isHidden = false
            lblExpire.text = viewModel.expiryText()
            totalsStack.isHidden = false
            fundView.isHidden = viewModel.fundingFee == 0
            lblFundFeeValue.text = viewModel.fundingFeeText
            lblFundFeeFiat.text = viewModel.fundingFeeFiatText
            let amountAndFeeText = viewModel.amountAndFeeText
            lblAmountValue.text = amountAndFeeText.0
            lblAmountFiat.text = amountAndFeeText.1
            if !viewModel.description.isEmpty {
                [lblNoteTitle, noteView].forEach {
                    $0?.isHidden = false
                }
                lblNoteTitle.text = "id_note".localized
                lblNoteValue.text = viewModel.description
            }
            switch viewModel.type {
            case .lwkSwap:
                viewModel.startMonitoring()
            default:
                break
            }
        case .failure(let err):
            activityIndicator.stopAnimating()
            showAlert(title: "", message: "\(err.localizedDescription)") { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }
    func imgToShare() async -> UIImage {
        guard let text = viewModel.bolt11 else { return UIImage() }
        let frame = CGRect(x: 0.0, y: 0.0, width: 256, height: 256)
        return await QRGenerator()
            .generateStatic(text: text, size: frame.size, padding: 16, screenScale: UIScreen.main.scale) ?? UIImage()
    }
    @objc func copyToClipboard(_ sender: Any? = nil) {
        guard let text = viewModel.bolt11 else { return }
//        let data = AnalyticsManager.ReceiveAddressData(type: self.isBipAddress(text) ? AnalyticsManager.ReceiveAddressType.uri : AnalyticsManager.ReceiveAddressType.address,
//                                                       media: AnalyticsManager.ReceiveAddressMedia.text,
//                                                       method: AnalyticsManager.ReceiveAddressMethod.copy)
//        AnalyticsManager.shared.receiveAddress(account: AccountsRepository.shared.current,
//                                               walletItem: viewModel.account,
//                                               data: data)
        UIPasteboard.general.string = text
        switch viewModel.type {
        case .bolt11, .lwkSwap:
            DropAlert().info(message: "Invoice copied to clipboard".localized, delay: 1.0)
        default:
            DropAlert().info(message: "id_address_copied_to_clipboard".localized, delay: 1.0)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    func magnifyQR() {
        let stb = UIStoryboard(name: "Qrcode", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "MagnifyQRViewController") as? MagnifyQRViewController {
            vc.qrTxt = viewModel.bolt11
            vc.textNoURI = viewModel.bolt11
            vc.showTxt = true
            vc.showBtn = true
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    @objc func longPressed(sender: UILongPressGestureRecognizer) {
        if sender.state == UIGestureRecognizer.State.began {
            magnifyQR()
        }
    }
    func dialogFundingFee() {
        let storyboard = UIStoryboard(name: "ReceiveFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogFundingFeeViewController") { coder in
            DialogFundingFeeViewController(coder: coder)
        }
        // vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: false, completion: nil)
    }
    @IBAction func btnFundFee(_ sender: Any) {
        dialogFundingFee()
    }
    @IBAction func btnQRCode(_ sender: Any) {
        copyToClipboard()
    }
    @IBAction func btnMagnify(_ sender: Any) {
        magnifyQR()
    }
    @IBAction func btnCopyAddress(_ sender: Any) {
        copyToClipboard()
    }
    @IBAction func btnShare(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "id_share".localized,
                                               type: .sharePrefs,
                                               items: SharePrefs.getItems(true))
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
}
extension LNInvoiceViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .moreOptPrefs:
            break
        case .sharePrefs:

            switch SharePrefs(rawValue: index) {
            case .none:
                return
            case .address, .invoice:
                let uri = viewModel.bolt11
                let activityViewController = UIActivityViewController(activityItems: [uri ?? ""], applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = self.view
                self.present(activityViewController, animated: true, completion: nil)
//                let data = AnalyticsManager.ReceiveAddressData(
//                    type: self.isBipAddress(uri ?? "") ? AnalyticsManager.ReceiveAddressType.uri : AnalyticsManager.ReceiveAddressType.address,
//                    media: AnalyticsManager.ReceiveAddressMedia.text,
//                    method: AnalyticsManager.ReceiveAddressMethod.share)
//                AnalyticsManager.shared.receiveAddress(
//                    account: AccountsRepository.shared.current,
//                    walletItem: viewModel.account,
//                    data: data)
            case .qr:
//                let uri = viewModel.bolt11
//                let data = AnalyticsManager.ReceiveAddressData(
//                    type: self.isBipAddress(uri ?? "") ? AnalyticsManager.ReceiveAddressType.uri : AnalyticsManager.ReceiveAddressType.address,
//                    media: AnalyticsManager.ReceiveAddressMedia.image,
//                    method: AnalyticsManager.ReceiveAddressMethod.share)
//                AnalyticsManager.shared.receiveAddress(
//                    account: AccountsRepository.shared.current,
//                    walletItem: viewModel.account,
//                    data: data)
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
            }
        default:
            break
        }
    }
}
