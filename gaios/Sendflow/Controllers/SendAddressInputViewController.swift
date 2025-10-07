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
    @IBOutlet weak var lblPlaceholder: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
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
        title = "id_send".localized
        lblSubtitle.text = "id_recipient".localized
        lblInvalid.text = "id_invalid_address".localized
        btnQR.setTitle("id_scan_qr_code".localized, for: .normal)
        btnPaste.setTitle("id_paste".localized, for: .normal)
        btnPaste.setImage(UIImage(named: "ic_clipboard")?.maskWithColor(color: UIColor.gBlackBg()), for: .normal)
        btnNext.setTitle("id_next".localized, for: .normal)
        if viewModel.txType == .sweep {
            lblPlaceholder.text = "id_enter_a_private_key_to_sweep".localized
        } else {
            lblPlaceholder.text = "id_enter_an_address_or_invoice".localized
        }
        addressTextView.textContainer.maximumNumberOfLines = 8
        addressTextView.textContainer.lineBreakMode = .byTruncatingTail
    }

    func setStyle() {
        infoBg.cornerRadius = 4.0
        textBg.setStyle(CardStyle.defaultStyle)
        infoIcon.image = UIImage(named: "ic_lightning_info")!.maskWithColor(color: .white)
        lblInvalid.setStyle(.txt)
        btnQR.setStyle(.inline)
        btnPaste.setStyle(.primary)
        lblPlaceholder.setStyle(.txtCard)
        lblSubtitle.setStyle(.txtCard)
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
            if (
                text ?? "").starts(with: "InvalidBolt11Invoice") {
                lblInvalid.text = "Invalid invoice. Paste a standard bolt11 invoice with an amount."
            } else {
                lblInvalid.text = text?.localized ?? ""
            }
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
        case .success:
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
        hidePlaceHolder(!emptyText)
    }

    func nextLwkLightning() {
        if viewModel.preferredAccount == nil && viewModel.liquidSubaccountsWithFunds.count >= 1 {
            // open liquid subaccount selection: go in account/asset screen
            var accounts = viewModel.liquidSubaccountsWithFunds
            if let lightningSubaccount = viewModel.lightningSubaccount {
                accounts.insert(lightningSubaccount, at: 0)
            }
            let model = AccountAssetViewModel(
                accounts: accounts,
                createTx: viewModel.createTx,
                funded: true,
                showBalance: true,
                showAssets: false)
            presentAccountAssetViewController(model: model)
        } else if let subaccount = viewModel.preferredAccount ?? viewModel.liquidSubaccountsWithFunds.first {
            // use the preselected subaccount or not first empty subaccount
            didSelectAccountAsset(
                account: subaccount,
                asset: AssetInfo.lbtc
            )
        } else {
            enableError(true, text: "id_insufficient_funds".localized)
        }
    }
    func nextBreezLightning() {
        guard let createTx = viewModel.createTx else { return }
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
            presentSendForWithdraw(requestData: data)
        default:
            if createTx.anyAmounts ?? false {
                presentSendAmountViewController()
            } else {
                createBreezLightningAndPushSendTxConfirmViewController()
            }
        }
    }
    func nextLiquid() {
        if viewModel.liquidSubaccounts.isEmpty {
            enableError(true, text: "Miss a liquid subaccount".localized)
        } else if viewModel.liquidSubaccountsWithFunds.isEmpty {
            // check there are any liquid funds: display dialog
            enableError(true, text: "id_insufficient_funds".localized)
        } else if let account = viewModel.preferredAccount {
            viewModel.createTx?.subaccount = account
            if let assetId = viewModel.assetId ?? viewModel.createTx?.assetId {
                viewModel.createTx?.assetId = assetId
            }
            presentSendAmountViewController()
        } else if viewModel.liquidSubaccountsWithFunds.count == 1,
                let subaccount = viewModel.liquidSubaccountsWithFunds.first {
            // preselect the liquid subaccount: go in amount screen
            if let assetId = viewModel.assetId ?? viewModel.createTx?.assetId {
                viewModel.createTx?.assetId = assetId
                viewModel.createTx?.subaccount = subaccount
                presentSendAmountViewController()
            } else if subaccount.manyAssets == 1 {
                viewModel.createTx?.subaccount = subaccount
                presentSendAmountViewController()
            } else {
                let model = AccountAssetViewModel(
                    accounts: viewModel.liquidSubaccountsWithFunds,
                    createTx: viewModel.createTx,
                    funded: true,
                    showBalance: true,
                    showAssets: true)
                presentAccountAssetViewController(model: model)
            }
        } else {
            // open liquid subaccount selection: go in account/asset screen
            let model = AccountAssetViewModel(
                accounts: viewModel.liquidSubaccountsWithFunds,
                createTx: viewModel.createTx,
                funded: true,
                showBalance: true,
                showAssets: true)
            presentAccountAssetViewController(model: model)
        }
    }
    func nextBitcoin() {
        if viewModel.bitcoinSubaccounts.isEmpty {
            enableError(true, text: "Miss a bitcoin subaccount".localized)
        } else if viewModel.bitcoinSubaccountsWithFunds.isEmpty {
            // check there are any bitcoin funds: display dialog
            enableError(true, text: "id_insufficient_funds".localized)
        } else if let account = viewModel.preferredAccount {
            viewModel.createTx?.subaccount = account
            if let assetId = viewModel.assetId, assetId != AssetInfo.btcId {
                viewModel.createTx?.assetId = viewModel.assetId
            }
            presentSendAmountViewController()
        } else if viewModel.bitcoinSubaccountsWithFunds.count == 1 {
            // preselect the bitcoin subaccount: go in amount screen
            viewModel.createTx?.subaccount = viewModel.bitcoinSubaccountsWithFunds.first
            presentSendAmountViewController()
        } else {
            // open bitcoin subaccount selection: go in account/asset screen
            let model = AccountAssetViewModel(
                accounts: viewModel.bitcoinSubaccountsWithFunds,
                createTx: viewModel.createTx,
                funded: true,
                showBalance: true,
                showAssets: false)
            presentAccountAssetViewController(model: model)
        }
    }

    @MainActor
    func next() {
        guard let createTx = viewModel.createTx else { return }
        if createTx.txType == .sweep {
            presentSendAmountViewController()
        } else if createTx.txType == .psbt {
            createPsbtAndPushSendTxConfirmViewController()
        } else if createTx.txType == .lwkSwap {
            nextLwkLightning()
        } else if createTx.isLightning {
            nextBreezLightning()
        } else if createTx.isBitcoin {
            nextBitcoin()
        } else if createTx.isLiquid {
            nextLiquid()
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
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController {
            vc.viewModel = ReceiveViewModel()
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

    func presentAccountAssetViewController(model: AccountAssetViewModel) {
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountAssetViewController") as? AccountAssetViewController {
            vc.viewModel = model
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: true)
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

    func pushSendTxConfirmViewController(model: SendTxConfirmViewModel) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendTxConfirmViewController") as? SendTxConfirmViewController {
            vc.viewModel = model
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func pushSendLightningViewController(model: SendLightningViewModel) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendLightningViewController") as? SendLightningViewController {
            vc.viewModel = model
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    
    func createBreezLightningAndPushSendTxConfirmViewController() {
        Task {
            let task = Task.detached() { [weak self] in
                try await self?.viewModel.createBreezLightningTransaction()
            }
            switch await task.result {
            case .success(let tx):
                if let tx = tx {
                    let model = viewModel.sendTxConfirmViewModel(tx: tx)
                    self.pushSendTxConfirmViewController(model: model)
                }
            case .failure(let err):
                self.enableError(true, text: err.localizedDescription)
            }
        }
    }

    func createLwkLightningAndPushSendLightningViewController() {
        Task {
            startLoader(message: "id_loading".localized)
            let task = Task.detached() { [weak self] in
                try await self?.viewModel.checkLwkLimits()
                return try await self?.viewModel.sendLightningViewModel()
            }
            switch await task.result {
            case .success(let model):
                stopLoader()
                if let model = model {
                    self.pushSendLightningViewController(model: model)
                }
            case .failure(let err):
                stopLoader()
                self.enableError(true, text: err.description().localized)
            }
        }
    }

    func createPsbtAndPushSendTxConfirmViewController() {
        Task {
            startLoader(message: "id_loading".localized)
            let task = Task.detached() { [weak self] in
                try await self?.viewModel.getTransactionFromPsbt()
            }
            switch await task.result {
            case .success(let tx):
                stopLoader()
                if let tx = tx {
                    let model = viewModel.sendPsbtConfirmViewModel(tx: tx)
                    self.pushSendTxConfirmViewController(model: model)
                }
            case .failure(let err):
                stopLoader()
                self.enableError(true, text: err.localizedDescription)
            }
        }
    }

    @objc func triggerTextChange() {
        Task { [weak self] in await self?.validate() }
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
        viewModel.input = addressTextView.text
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0.3)
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

extension SendAddressInputViewController: AccountAssetViewControllerDelegate {
    func didSelectAccountAsset(account: WalletItem, asset: AssetInfo) {
        if account.btc ?? 0 < viewModel.createTx?.satoshi ?? 0 {
            self.enableError(true, text: "id_insufficient_funds".localized)
            return
        }
        if account.isLightning {
            nextBreezLightning()
            return
        }
        viewModel.createTx?.subaccount = account
        viewModel.createTx?.assetId = asset.assetId
        switch viewModel.createTx?.txType {
        case .lwkSwap:
            createLwkLightningAndPushSendLightningViewController()
        case .psbt:
            createPsbtAndPushSendTxConfirmViewController()
        default:
            presentSendAmountViewController()
        }
    }
}
