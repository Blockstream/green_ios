import Foundation
import UIKit
import gdk
import greenaddress
import core
import BreezSDK
import lightning

class SendAddressInputViewController: KeyboardViewController {

    @IBOutlet weak var infoBg: UIView!
    @IBOutlet weak var textBg: UIView!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoIcon: UIImageView!
    @IBOutlet weak var lblInvalid: UILabel!
    @IBOutlet weak var btnClear: UIButton!
    @IBOutlet weak var btnPasteSmall: UIButton!
    @IBOutlet weak var lblPlaceholder: UILabel!

    @IBOutlet weak var addressTextView: UITextView!
    @IBOutlet weak var btnQR: UIButton!
    @IBOutlet weak var btnPaste: UIButton!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!

    var viewModel: SendAddressInputViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: "id_back".localized, style: .plain, target: nil, action: nil)

        addressTextView.text = ""
        reload()
        enableError(false)

        if let text = viewModel.input {
            addressTextView.text = text
            reload()
            Task { [weak self] in await self?.validate() }
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
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.anchorBottom.constant = 20.0
        })
    }

    func setContent() {
        title = "id_recipient".localized
        // addressTextView.place = "Enter address or invoice".localized
        lblInvalid.text = "id_invalid_address".localized
        btnQR.setTitle("id_scan_qr_code".localized, for: .normal)
        btnPaste.setTitle("id_paste".localized, for: .normal)
        btnPasteSmall.setTitle("id_paste".localized, for: .normal)
        btnNext.setTitle("id_next".localized, for: .normal)
        if viewModel.txType == .sweep {
            lblPlaceholder.text = "id_enter_a_private_key_to_sweep".localized
        } else {
            lblPlaceholder.text = "Enter Address or Invoice".localized
        }
        addressTextView.textContainer.maximumNumberOfLines = 8
        addressTextView.textContainer.lineBreakMode = .byTruncatingTail
    }

    func setStyle() {
        infoBg.cornerRadius = 4.0
        textBg.cornerRadius = 4.0
        infoIcon.image = UIImage(named: "ic_lightning_info")!.maskWithColor(color: .white)
        lblInvalid.setStyle(.txt)
        btnQR.setStyle(.inline)
        btnPaste.setStyle(.primary)
        btnPasteSmall.setStyle(.inlineGray)
        lblPlaceholder.setStyle(.txtCard)
        btnNextEnabled = true
    }

    func hidePlaceHolder(_ hidden: Bool) {
        lblPlaceholder.isHidden = hidden
    }

    var btnNextEnabled: Bool = false {
        didSet {
            btnNext.isEnabled = btnNextEnabled
            if btnNextEnabled {
                btnNext.setStyle(.primary)
            } else {
                btnNext.setStyle(.primaryGray)
            }
        }
    }

    @MainActor
    func enableError(_ enable: Bool, text: String? = nil) {
        if enable {
            infoBg.backgroundColor = UIColor.gRedWarn()
            infoView.isHidden = false
            lblInvalid.text = text?.localized ?? ""
        } else {
            infoBg.backgroundColor = .clear
            infoView.isHidden = true
            lblInvalid.text = ""
        }
    }

    @IBAction func btnQR(_ sender: Any) {
        presentQrcodeScanner()
    }

    @IBAction func btnPaste(_ sender: Any) {
        if let text = UIPasteboard.general.string {
            addressTextView.text = text
            viewModel.input = text
            reload()
            Task { [weak self] in await self?.validate() }
        }
    }

    @IBAction func btnPasteSmall(_ sender: Any) {
        if let text = UIPasteboard.general.string {
            addressTextView.text = text
            viewModel.input = text
            reload()
            Task { [weak self] in await self?.validate() }
        }
    }

    @IBAction func btnClear(_ sender: Any) {
        addressTextView.text = ""
        enableError(false)
        addressTextView.endEditing(true)
        reload()
    }

    @IBAction func btnNext(_ sender: Any) {
        if let text = addressTextView.text {
            viewModel.input = text
            Task { [weak self] in await self?.validate() }
        }
    }

    func validate() async {
        btnNext.setStyle(.primaryDisabled)
        let res = await Task.detached {
            try await self.viewModel.parse()
            try await self.viewModel.loadSubaccountBalance()
            
        }.result
        switch res {
        case .success():
            enableError(false)
            btnNext.setStyle(.primary)
            next()
        case .failure(let error):
            enableError(true, text: error.description())
        }
    }

    @MainActor
    func reload() {
        let emptyText = addressTextView.text?.isEmpty ?? true
        btnClear.isHidden = emptyText
        btnNext.isHidden = emptyText
        btnPaste.isHidden = !emptyText
        btnPasteSmall.isHidden = !emptyText
        hidePlaceHolder(!emptyText)
    }

    @MainActor
    func next() {
        guard let createTx = viewModel.createTx else { return }
        if viewModel.txType == .sweep {
            presentSendAmountViewController()
            return
        }

        if createTx.txType == .psbt {
            presentSendPsbtConfirmViewController()
        } else if createTx.isLightning {
            if let error = createTx.error {
                enableError(true, text: error.localized)
                return
            }
            // lightning account: go in amount screen
            switch createTx.lightningType {
            case .lnUrlAuth(let data):
                // open LNURL-Auth page
                presentLtAuthViewController(requestData: data)
            case .lnUrlWithdraw(let data):
//                presentLtWithdrawViewController(requestData: data)
                presentSendForWithdraw(requestData: data)
            default:
                if createTx.anyAmounts ?? false {
                    presentSendAmountViewController()
                } else {
                    Task { [weak self] in await self?.presentSendTxConfirmViewController() }
                }
            }
        } else if createTx.isBitcoin {
            // lightning liquid
            if viewModel.bitcoinSubaccounts.isEmpty {
                enableError(true, text: "Miss a bitcoin subaccount".localized)
            } else if viewModel.bitcoinSubaccountsWithFunds.isEmpty {
                // check there are any bitcoin funds: display dialog
                enableError(true, text: "id_insufficient_funds".localized)
            } else if viewModel.bitcoinSubaccountsWithFunds.count == 1 {
                // preselect the bitcoin subaccount: go in amount screen
                viewModel.createTx?.subaccount = viewModel.bitcoinSubaccountsWithFunds.first
                presentSendAmountViewController()
            } else if viewModel.bitcoinSubaccountsWithFunds.count > 1 {
                // open bitcoin subaccount selection: go in account/asset screen
                presentAccountAssetViewController()
            }
        } else if createTx.isLiquid {
            // lightning liquid
            if viewModel.liquidSubaccounts.isEmpty {
                enableError(true, text: "Miss a liquid subaccount".localized)
            } else if viewModel.liquidSubaccountsWithFunds.isEmpty {
                // check there are any liquid funds: display dialog
                enableError(true, text: "id_insufficient_funds".localized)
            } else if viewModel.liquidSubaccountsWithFunds.count == 1,
                      let subaccount = viewModel.liquidSubaccountsWithFunds.first {
                // preselect the liquid subaccount: go in amount screen
                if let assetId = viewModel.createTx?.assetId, viewModel.createTx?.bip21 ?? false {
                    viewModel.createTx?.subaccount = subaccount
                    presentSendAmountViewController()
                } else if subaccount.manyAssets == 1 {
                    viewModel.createTx?.subaccount = subaccount
                    presentSendAmountViewController()
                } else {
                    presentAccountAssetViewController()
                }
            } else {
                // open liquid subaccount selection: go in account/asset screen
                presentAccountAssetViewController()
            }
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

    func presentReceiveViewController() {
        guard let createTx = viewModel.createTx else { return }
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController {
            var subaccounts = [WalletItem]()
            if createTx.isBitcoin {
                subaccounts = viewModel.bitcoinSubaccounts
            } else {
                subaccounts = viewModel.liquidSubaccounts
            }
            vc.viewModel = ReceiveViewModel(account: subaccounts.first!,
                                            accounts: subaccounts)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func presentLtAuthViewController(requestData: LnUrlAuthRequestData) {
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTAuthViewController") as? LTAuthViewController {
            vc.requestData = requestData
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func presentLtWithdrawViewController(requestData: LnUrlWithdrawRequestData) {
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTWithdrawViewController") as? LTWithdrawViewController {
            vc.requestData = requestData
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func presentAccountAssetViewController() {
        guard let createTx = viewModel.createTx else { return }
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountAssetViewController") as? AccountAssetViewController {
            vc.viewModel = viewModel.accountAssetViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func presentSendForWithdraw(requestData: LnUrlWithdrawRequestData) {

        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAmountViewController") as? SendAmountViewController {
            vc.viewModel = SendAmountViewModel(createTx: viewModel.createTx!)
            vc.withdrawData = requestData
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func presentSendAmountViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAmountViewController") as? SendAmountViewController {
            vc.viewModel = SendAmountViewModel(createTx: viewModel.createTx!)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func presentSendTxConfirmViewController() async {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendTxConfirmViewController") as? SendTxConfirmViewController {
            vc.viewModel = await viewModel.sendTxConfirmViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func presentSendPsbtConfirmViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendTxConfirmViewController") as? SendTxConfirmViewController {
            Task {
                do {
                    startLoader(message: "id_loading".localized)
                    let vm = try await viewModel.sendPsbtConfirmViewModel()
                    stopLoader()
                    await MainActor.run {
                        vc.viewModel = vm
                        navigationController?.pushViewController(vc, animated: true)
                    }
                } catch {
                    stopLoader()
                    showError(error.description()?.localized ?? "id_operation_failure".localized)
                }
            }
        }
    }
}

extension SendAddressInputViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        hidePlaceHolder(true)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        hidePlaceHolder(!addressTextView.text.isEmpty)
    }

    func textViewDidChange(_ textView: UITextView) {
        reload()
    }
}

extension SendAddressInputViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        var input = value.result
        if let psbt = value.bcur?.psbt {
            viewModel.txType = .psbt
            input = psbt
        }
        addressTextView.text = input
        viewModel.input = input
        reload()
        Task { [weak self] in
            await self?.validate()
        }
    }
    func didStop() {
    }
}
