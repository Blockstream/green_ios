import Foundation
import UIKit
import gdk
import greenaddress
import core
import BreezSDK
import lightning

class SendAddressViewController: KeyboardViewController {

    @IBOutlet weak var infoBg: UIView!
    @IBOutlet weak var textBg: UIView!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoIcon: UIImageView!
    @IBOutlet weak var lblInvalid: UILabel!
    @IBOutlet weak var btnClear: UIButton!
    @IBOutlet weak var lblPlaceholder: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var addressTextView: UITextView!
    @IBOutlet weak var btnQR: UIButton!
    @IBOutlet weak var btnPaste: UIButton!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!

    private let viewModel: SendAddressViewModel

    init?(coder: NSCoder, viewModel: SendAddressViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        reload()
        viewModel.onStateChanged = { [weak self] in
            self?.reload()
        }
    }

    func setContent() {
        title = "id_send".localized
        lblSubtitle.text = "id_recipient".localized
        lblInvalid.text = "id_invalid_address".localized
        btnQR.setTitle("id_scan_qr_code".localized, for: .normal)
        btnPaste.setTitle("id_paste".localized, for: .normal)
        infoIcon.image = UIImage(named: "ic_lightning_info")!.maskWithColor(color: .white)
        btnPaste.setImage(UIImage(named: "ic_clipboard")?.maskWithColor(color: UIColor.gBlackBg()), for: .normal)
        btnNext.setTitle("id_next".localized, for: .normal)
        if viewModel.sweepPrivateKey {
            lblPlaceholder.text = "id_enter_a_private_key_to_sweep".localized
        } else if let subaccount = viewModel.subaccount {
            if let assetId = viewModel.assetId, assetId == AssetInfo.lbtcId || assetId == AssetInfo.lightningId {
                lblPlaceholder.text = "id_enter_an_address_or_invoice".localized
            } else {
                lblPlaceholder.text = "id_enter_an_address".localized
            }
        } else {
            lblPlaceholder.text = "id_enter_an_address_or_invoice".localized
        }
    }

    func setStyle() {
        infoBg.cornerRadius = 4.0
        textBg.setStyle(CardStyle.defaultStyle)
        lblInvalid.setStyle(.txt)
        btnQR.setStyle(.inline)
        btnPaste.setStyle(.primary)
        lblPlaceholder.setStyle(.txtCard)
        lblSubtitle.setStyle(.txtCard)
        addressTextView.textContainer.maximumNumberOfLines = 8
        addressTextView.textContainer.lineBreakMode = .byTruncatingTail
    }

    @MainActor
    @objc private func textChanged() {
        Task { await self.validate() }
    }

    @MainActor
    private func reload() {
        // enable continuation
        btnNext.isEnabled = viewModel.canContinue
        btnNext.setStyle(viewModel.canContinue ? .primary : .primaryGray)
        // show error message
        if let error = viewModel.error {
            infoBg.backgroundColor = UIColor.gRedWarn()
            infoView.isHidden = false
            lblInvalid.text = error.description().localized
        } else {
            infoBg.backgroundColor = .clear
            infoView.isHidden = true
            lblInvalid.text = ""
        }
        // show/hide action buttons
        let emptyText = addressTextView.text?.isEmpty ?? true
        btnClear.isHidden = emptyText
        btnNext.isHidden = emptyText
        btnPaste.isHidden = !emptyText
        lblPlaceholder.isHidden = !emptyText
    }
    @IBAction func btnQR(_ sender: Any) {
        presentQrcodeScanner()
    }

    @IBAction func btnPaste(_ sender: Any) {
        if let text = UIPasteboard.general.string {
            addressTextView.text = text
            reload()
            Task { [weak self] in await self?.validate() }
        }
    }

    @IBAction func btnClear(_ sender: Any) {
        viewModel.canContinue = false
        viewModel.error = nil
        addressTextView.text = ""
        addressTextView.endEditing(true)
        reload()
    }

    @IBAction func btnNext(_ sender: Any) {
        Task { [weak self] in await self?.validate() }
    }

    func validate() async {
        if let text = addressTextView.text {
            await viewModel.validate(text: text)
        }
    }

    func presentQrcodeScanner() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogScanViewController") as? DialogScanViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.index = nil
            vc.delegate = self
            present(vc, animated: false, completion: nil)
            AnalyticsManager.shared.scanQr(account: AccountsRepository.shared.current,
                                           screen: .send)
        }
    }  
}

extension SendAddressViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        lblPlaceholder.isHidden = true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        lblPlaceholder.isHidden = !textView.text.isEmpty
    }

    func textViewDidChange(_ textView: UITextView) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.textChanged), object: nil)
        perform(#selector(self.textChanged), with: nil, afterDelay: 0.3)
    }
}
extension SendAddressViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        var input = value.result
        if let psbt = value.bcur?.psbt {
            input = psbt
        }
        addressTextView.text = input
        reload()
        Task { [weak self] in
            await self?.validate()
        }
    }
    func didStop() {
    }
}

extension SendAddressViewController: SendFlowErrorDisplayable {
    func handleSendFlowError(_ error: Error?) {
        viewModel.canContinue = false
        viewModel.error = error
        reload()
    }
}
