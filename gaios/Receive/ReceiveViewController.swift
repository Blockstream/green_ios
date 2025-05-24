import Foundation
import BreezSDK
import UIKit
import LinkPresentation
import gdk
import hw
import Combine
import core

public enum TransactionBaseType: UInt32 {
    case BTC = 0
    case FIAT = 1
}

enum ReceiveSection: Int, CaseIterable {
    case backup
    case asset
    case account
    case amount
    case address
    case infoReceiveAmount
    case infoExpiredIn
    case note
}

class ReceiveViewController: KeyboardViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnShare: UIButton!
    @IBOutlet weak var btnVerify: UIButton!
    @IBOutlet weak var btnOnChain: UIButton!
    @IBOutlet weak var btnConfirm: UIButton!
    @IBOutlet weak var stackBottom: NSLayoutConstraint!
    @IBOutlet weak var accountStack: UIStackView!
    @IBOutlet weak var lblAccount: UILabel!
    @IBOutlet weak var btnAccount: UIButton!

    private var selectedType = TransactionBaseType.BTC
    private var lightningAmountEditing = true
    private var newAddressToken, invoicePaidToken: NSObjectProtocol?
    private var headerH: CGFloat = 36.0
    private var loading = true
    private var keyboardVisible = false
    var viewModel: ReceiveViewModel!
    weak var verifyOnDeviceViewController: HWDialogVerifyOnDeviceViewController?

    var hideVerify: Bool {
        return !(viewModel.wm.account.isJade && !viewModel.wm.account.isWatchonly && !viewModel.account.isLightning)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        register()
        setContent()
        setStyle()

        AnalyticsManager.shared.recordView(.receive, sgmt: AnalyticsManager.shared.subAccSeg(AccountsRepository.shared.current, walletItem: viewModel.account))

        didSelectAccount(viewModel.account)
        // always nag even after dismiss
        BackupHelper.shared.cleanDismissedCache(walletId: viewModel.wm.account.id, position: .receive)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
        invoicePaidToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: EventType.InvoicePaid.rawValue), object: nil, queue: .main, using: invoicePaid)
        newAddressToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: EventType.AddressChanged.rawValue), object: nil, queue: .main, using: newAddress)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = newAddressToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = invoicePaidToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reloadSections([.backup], animated: false)
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let inset = (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) - 5
        keyboardVisible = true
        stackBottom.constant = keyboardFrame.height - inset
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.view.layoutIfNeeded()
            let network = self?.viewModel.account.gdkNetwork
            self?.btnOnChain.isHidden = !(network?.lightning ?? false) || self?.keyboardVisible ?? false
        })
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        keyboardVisible = false
        stackBottom.constant = 0.0
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.view.layoutIfNeeded()
            let network = self?.viewModel.account.gdkNetwork
            self?.btnOnChain.isHidden = !(network?.lightning ?? false) || self?.keyboardVisible ?? false
        })
    }

    func register() {
        ["AlertCardCell", "ReceiveAddressCell", "AmountCell", "LTInfoCell", "LTNoteCell", "ReceiveAssetCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    func setContent() {
        title = "id_receive".localized
        btnShare.setTitle("id_share".localized, for: .normal)
        btnVerify.setTitle("id_verify_on_device".localized, for: .normal)
        btnConfirm.setTitle("id_confirm".localized, for: .normal)
    }

    func setStyle() {
        btnShare.setStyle(hideVerify ? .primary : .outlined)
        btnShare.setTitleColor(.white, for: .normal)
        btnOnChain.semanticContentAttribute = UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? .forceLeftToRight : .forceRightToLeft
        btnVerify.setStyle(.primary)
        stateDidChange(.disabled)
    }

    var sections: [ReceiveSection] {
        switch viewModel.type {
        case .bolt11:
            if lightningAmountEditing {
                return [.asset, .account, .amount]
            } else if viewModel.description == nil {
                return [.asset, .account, .amount, .address, .infoReceiveAmount, .infoExpiredIn]
            } else {
                return ReceiveSection.allCases
            }
        case .swap:
            return [.backup, .asset, .account, .address]
        case .address:
            return [.backup, .asset, .account, .address]
        }
    }

    @MainActor
    func reload() {
        let network = viewModel.account.gdkNetwork
        btnOnChain.isHidden = !network.lightning || keyboardVisible
        btnConfirm.isHidden = !(network.lightning && lightningAmountEditing)
        btnShare.isHidden = !(!network.lightning || !lightningAmountEditing)
        if viewModel.type == .swap {
            btnConfirm.isHidden = true
            btnShare.isHidden = false
        }
        btnVerify.isHidden = hideVerify
        btnOnChain.setTitle(viewModel.type == .bolt11 ? "id_show_onchain_address".localized : "id_show_lightning_invoice".localized, for: .normal)
        accountStack.isHidden = true
        reloadNavigationBtns()
        viewModel.reloadBackupCards()
        tableView.reloadData()
    }

    func reloadNavigationBtns() {
        if viewModel.account.networkType.lightning {
            let btnNote = UIButton(type: .system)
            btnNote.setStyle(.inline)
            btnNote.setTitle(Common.noteActionName(viewModel.description ?? ""), for: .normal)
            btnNote.addTarget(self, action: #selector(editNoteBtnTapped), for: .touchUpInside)
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: btnNote)
        } else {
            let optBtn = UIButton(type: .system)
            optBtn.setImage(UIImage(named: "ic_dots_three"), for: .normal)
            optBtn.addTarget(self, action: #selector(optBtnTap), for: .touchUpInside)
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: optBtn)
        }
    }

    func invoicePaid(_ notification: Notification? = nil) {
        Task {
            if let invoice = notification?.object as? InvoicePaidDetails {
                if let vm = try await viewModel.ltSuccessViewModel(details: invoice) {
                    presentLTSuccessViewController(model: vm)
                }
            }
        }
    }

    func newAddress(_ notification: Notification? = nil) {
        Task { [weak self] in
            await self?.newAddressAsync()
        }
    }

    func newAddressAsync() async {
        loading = true
        reload()
        let task = Task.detached(priority: .background) { [weak self] in
            try await self?.viewModel?.newAddress()
        }
        switch await task.result {
        case .success:
            loading = false
            reload()
        case .failure(let err):
            error(err)
        }
    }

    @MainActor
    func error(_ err: Error) {
         let msg = err.description()
        if msg.contains("Swap in progress") {
            showError("id_there_is_already_a_swap_in".localized)
            return
        }
        let request = ZendeskErrorRequest(
            error: msg.localized,
            network: viewModel.account.networkType,
            paymentHash: nil,
            screenName: "Receive")
        presentContactUsViewController(request: request)
    }

    @MainActor
    func presentDialogAccountsViewController() {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAccountsViewController") as? DialogAccountsViewController {
            vc.viewModel = viewModel.dialogAccountsModel()
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
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

    func isBipAddress(_ addr: String) -> Bool {
        return viewModel?.isBipAddress(addr) ?? false
    }

    @objc func copyToClipboard(_ sender: Any? = nil) {
        guard let text = viewModel.text else { return }
        let data = AnalyticsManager.ReceiveAddressData(type: self.isBipAddress(text) ? AnalyticsManager.ReceiveAddressType.uri : AnalyticsManager.ReceiveAddressType.address,
                                                       media: AnalyticsManager.ReceiveAddressMedia.text,
                                                       method: AnalyticsManager.ReceiveAddressMethod.copy)
        AnalyticsManager.shared.receiveAddress(account: AccountsRepository.shared.current,
                                               walletItem: viewModel.account,
                                               data: data)
        UIPasteboard.general.string = text
        DropAlert().info(message: "id_address_copied_to_clipboard".localized, delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func imgToShare() -> UIImage {
        guard let text = viewModel.text else { return UIImage() }
        let frame = CGRect(x: 0.0, y: 0.0, width: 256, height: 256)
        return QRImageGenerator.imageForTextWhite(text: text, frame: frame) ?? UIImage()
    }

    @objc func helpBtnTap() {
        SafeNavigationManager.shared.navigate(ExternalUrls.receiveTransactionHelp)
    }

    func optRequestAmount() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAmountViewController") as? DialogAmountViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.wallet = viewModel.account
            vc.prefill = self.viewModel.satoshi
            present(vc, animated: false, completion: nil)
        }
    }

    func optSweep() {
        presentSendAddressInputViewController()
    }

    func presentSendAddressInputViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAddressInputViewController") as? SendAddressInputViewController {
            vc.viewModel = SendAddressInputViewModel(preferredAccount: viewModel.account, txType: .sweep)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func optAddressAuth() {
        let storyboard = UIStoryboard(name: "AddressAuth", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AddressAuthViewController") as? AddressAuthViewController {
            // add required model info
            vc.viewModel = AddressAuthViewModel(wallet: viewModel.account)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func didSelectAssetRow() {
        AnalyticsManager.shared.changeAsset(account: AccountsRepository.shared.current)
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AssetSelectViewController") as? AssetSelectViewController {
            vc.viewModel = viewModel.getAssetSelectViewModel()
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func onRefreshClick() {
        newAddress()
    }

    func magnifyQR() {
        let stb = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "MagnifyQRViewController") as? MagnifyQRViewController {
            vc.qrTxt = viewModel.text
            vc.textNoURI = viewModel.textNoURI
            vc.showTxt = true
            vc.showBtn = true
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    @MainActor
    func presentLTSuccessViewController(model: LTSuccessViewModel) {
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTSuccessViewController") as? LTSuccessViewController {
            vc.viewModel = model
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    @objc func editNoteBtnTapped() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogEditViewController") as? DialogEditViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.prefill = viewModel.description ?? ""
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    func showLightningFeeInfo() {
        SafeNavigationManager.shared.navigate( ExternalUrls.helpReceiveFees )
    }

    func showDialogInputDenominations() {
        let model = viewModel.dialogInputDenominationViewModel()
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogInputDenominationViewController") as? DialogInputDenominationViewController {
            vc.viewModel = model
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @objc func optBtnTap() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self

            vc.viewModel = DialogListViewModel(title: "id_more_options".localized,
                                               type: .moreOptPrefs,
                                               items: MoreOptPrefs.getItems(account: viewModel.account))
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func reloadSections(_ sections: [ReceiveSection], animated: Bool) {
        if animated {
            tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .fade)
        } else {
            UIView.performWithoutAnimation {
                tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }
    func backupAlertDismiss() {
        BackupHelper.shared.addToDismissed(walletId: viewModel.wm.account.id, position: .receive)
        viewModel.reloadBackupCards()
        reloadSections([.backup], animated: true)
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

    @IBAction func btnEdit(_ sender: Any) {
        optRequestAmount()
    }

    @IBAction func btnOptions(_ sender: Any) {
        optBtnTap()
    }

    @IBAction func btnVerify(_ sender: Any) {
        presentConnectViewController()
    }

    func verifyAddress() async {
        AnalyticsManager.shared.verifyAddressJade(account: AccountsRepository.shared.current, walletItem: viewModel.account)
        if let vm = viewModel.receiveVerifyOnDeviceViewModel() {
            presentVerifyOnDeviceViewController(viewModel: vm)
        }
        let task = Task.detached { [weak self] in
            try await self?.viewModel.validateHW()
        }
        switch await task.result {
        case .success(let success):
            verifyOnDeviceViewController?.dismiss()
            switch success {
            case .some(true):
                DropAlert().success(message: "id_the_address_is_valid".localized)
            case .none:
                DropAlert().error(message: "id_operation_failure".localized)
            case .some(false):
                DropAlert().error(message: "id_the_addresses_dont_match".localized)
            }
        case .failure(let error):
            verifyOnDeviceViewController?.dismiss()
            DropAlert().error(message: error.description().localized)
        }
    }

    @IBAction func btnConfirm(_ sender: Any) {
        if viewModel.satoshi != nil {
            lightningAmountEditing = false
            newAddress()
        }
    }

    @IBAction func btnOnChain(_ sender: Any) {
        viewModel.type = viewModel.type == .bolt11 ? .swap : .bolt11
        switch viewModel.type {
        case .bolt11:
            if viewModel.invoice == nil {
                newAddress()
            }
        case .swap:
            if viewModel.swap == nil {
                newAddress()
            }
        default:
            break
        }
        reload()
    }

    @IBAction func btnAccount(_ sender: Any) {
        presentDialogAccountsViewController()
    }
}

extension ReceiveViewController: AssetSelectViewControllerDelegate {

    func didSelectAnyAsset(_ type: AnyAssetType) {
        switch type {
        case .liquid:
            viewModel.asset = AssetInfo.lbtcId
            viewModel.anyAsset = type
            if !viewModel.account.networkType.liquid {
                if let account = viewModel.getAccounts().first {
                    viewModel.account = account
                }
            }
        case .amp:
            viewModel.anyAsset = type
            if viewModel.account.type != .amp {
                if let account = viewModel.getAccounts().first {
                    viewModel.account = account
                }
            }
        }
        reload()
        newAddress()
    }

    func didSelectAsset(_ assetId: String) {
        let info = WalletManager.current?.info(for: assetId)
        if info?.amp ?? false && !viewModel.hasSubaccountAmp() {
            DropAlert().warning(message: "Create Amp account to receive Amp asset")
            return
        }
        viewModel.asset = assetId
        viewModel.anyAsset = nil
        if (info?.isBitcoin ?? true && !viewModel.account.networkType.bitcoin) ||
            (info?.isLightning ?? true && !viewModel.account.networkType.lightning) ||
            (info?.amp ?? true && viewModel.account.type != .amp ) ||
            (info?.isLiquid ?? true && !viewModel.account.networkType.liquid) {
            if let account = viewModel.getAccounts().first {
                viewModel.account = account
                viewModel.type = account.gdkNetwork.lightning ? .bolt11 : .address
            }
        }
        reload()
        newAddress()
    }
}
extension ReceiveViewController: DialogAmountViewControllerDelegate {
    func didConfirm(satoshi: Int64?) {
        self.viewModel.satoshi = satoshi
        reload()
    }

    func didCancel() { }
}

extension ReceiveViewController: UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return ""
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return nil
    }

    @available(iOS 13.0, *)
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let image = imgToShare()
        let imageProvider = NSItemProvider(object: image)
        let metadata = LPLinkMetadata()
        metadata.imageProvider = imageProvider
        return metadata
    }
}

extension ReceiveViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .moreOptPrefs:

            if let item = MoreOptPrefs.getPrefs(account: viewModel.account)[safe: index] {
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
                let uri = viewModel.text
                let activityViewController = UIActivityViewController(activityItems: [uri ?? ""], applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = self.view
                self.present(activityViewController, animated: true, completion: nil)
                let data = AnalyticsManager.ReceiveAddressData(type: self.isBipAddress(uri ?? "") ? AnalyticsManager.ReceiveAddressType.uri : AnalyticsManager.ReceiveAddressType.address,
                                                               media: AnalyticsManager.ReceiveAddressMedia.text,
                                                               method: AnalyticsManager.ReceiveAddressMethod.share)
                AnalyticsManager.shared.receiveAddress(account: AccountsRepository.shared.current,
                                                       walletItem: viewModel.account,
                                                       data: data)
            case .qr:
                let uri = viewModel.text
                let image = imgToShare()
                let share = UIActivityViewController(activityItems: [image, self], applicationActivities: nil)
                self.present(share, animated: true, completion: nil)
                let data = AnalyticsManager.ReceiveAddressData(type: self.isBipAddress(uri ?? "") ? AnalyticsManager.ReceiveAddressType.uri : AnalyticsManager.ReceiveAddressType.address,
                                                               media: AnalyticsManager.ReceiveAddressMedia.image,
                                                               method: AnalyticsManager.ReceiveAddressMethod.share)
                AnalyticsManager.shared.receiveAddress(account: AccountsRepository.shared.current,
                                                       walletItem: viewModel.account,
                                                       data: data)
            }
        default:
            break
        }
    }
}

extension ReceiveViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case ReceiveSection.backup:
            return viewModel.backupCardCellModel.count
        case ReceiveSection.asset:
            return 1
        case ReceiveSection.account:
            return viewModel.getAccounts().count <= 1 ? 0 : 1
        case ReceiveSection.address:
            return 1
        case ReceiveSection.amount:
            return 1
        case ReceiveSection.infoReceiveAmount:
            return 1
        case ReceiveSection.infoExpiredIn:
            return 1
        case ReceiveSection.note:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case ReceiveSection.backup:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                let alertCard = viewModel.backupCardCellModel[indexPath.row]
                switch alertCard.type {
                case .backup:
                    cell.configure(alertCard,
                                   onLeft: {[weak self] in
                        if let vc = AccountNavigator.recover() {
                            self?.navigationController?.pushViewController(vc, animated: true)
                        }
                    },
                                   onRight: nil,
                                   onDismiss: { [weak self] in
                        self?.backupAlertDismiss()
                    })
                default:
                    break
                }
                cell.selectionStyle = .none
                return cell
            }
        case ReceiveSection.asset:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "ReceiveAssetCell") as? ReceiveAssetCell {
                let model = viewModel.receiveAssetCellModel
                cell.configure(model: viewModel.receiveAssetCellModel, onTap: { self.didSelectAssetRow() })
                cell.selectionStyle = .none
                return cell
            }
        case ReceiveSection.account:
            let cell = UITableViewCell()
            cell.backgroundColor = UIColor.gBlackBg()

            let label = UILabel()
            label.setStyle(.sectionTitle)
            label.text = "id_account".localized

            let button = UIButton(type: .system)
            button.setStyle(.sectionTitle)
            button.setTitle(viewModel.account.localizedName, for: .normal)
            button.addTarget(self, action: #selector(btnAccount(_:)), for: .touchUpInside)
            button.contentHorizontalAlignment = .right

            // Use SF Symbol for downward chevron and add a space
            let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
            chevron.tintColor = .white

            let rightStack = UIStackView(arrangedSubviews: [button, chevron])
            rightStack.axis = .horizontal
            rightStack.spacing = 8 // Add more space between button and chevron
            rightStack.alignment = .center

            let mainStack = UIStackView(arrangedSubviews: [label, rightStack])
            mainStack.axis = .horizontal
            mainStack.spacing = 8
            mainStack.alignment = .center
            mainStack.distribution = .equalSpacing

            cell.contentView.addSubview(mainStack)
            mainStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                mainStack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 25),
                mainStack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -25),
                mainStack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                mainStack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            cell.selectionStyle = .none
            return cell
        case ReceiveSection.amount:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AmountCell") as? AmountCell {
                let model = viewModel.amountCellModel
                cell.configure(model: model, delegate: self, enabled: lightningAmountEditing)
                cell.selectionStyle = .none
                return cell
            }
        case ReceiveSection.address:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "ReceiveAddressCell") as? ReceiveAddressCell {
                let model = viewModel.addressCellModel
                cell.configure(model: model, isAnimating: loading) { [weak self] in self?.copyToClipboard()
                } onRefreshClick: { [weak self] in
                    self?.onRefreshClick()
                } onLongpress: { [weak self] in
                    self?.magnifyQR()
                }
                cell.selectionStyle = .none
                return cell
            }
        case ReceiveSection.infoReceiveAmount:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "LTInfoCell") as? LTInfoCell {
                cell.configure(model: viewModel.infoReceivedAmountCellModel)
                cell.selectionStyle = .none
                return cell
            }
        case ReceiveSection.infoExpiredIn:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "LTInfoCell") as? LTInfoCell {
                cell.configure(model: viewModel.infoExpiredInCellModel)
                cell.selectionStyle = .none
                return cell
            }
        case ReceiveSection.note:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "LTNoteCell") as? LTNoteCell {
                cell.configure(model: viewModel.noteCellModel) { [weak self] in
                    self?.editNoteBtnTapped()
                }
                cell.selectionStyle = .none
                return cell
            }
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sections[section] {
        case ReceiveSection.asset:
            return headerH
        case ReceiveSection.account:
            return 0.1
        case ReceiveSection.address:
            return headerH
        case ReceiveSection.amount:
            return headerH
        case ReceiveSection.note:
            return headerH
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case ReceiveSection.backup:
            return nil
        case ReceiveSection.asset:
            return headerView("id_asset".localized)
        case ReceiveSection.account:
            return nil
        case ReceiveSection.address:
            switch viewModel.type {
            case .address:
                return headerView("id_address".localized)
            case .bolt11:
                return headerView("id_lightning_invoice".localized)
            case .swap:
                return headerView("id_onchain_address".localized)
            }
        case ReceiveSection.amount:
            return headerView("id_amount".localized)
        case ReceiveSection.note:
            return headerView("id_note".localized)
        case .infoReceiveAmount:
            return nil
        case .infoExpiredIn:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
}

extension ReceiveViewController {
    func headerView(_ txt: String) -> UIView {
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.gBlackBg()
        let title = UILabel(frame: .zero)
        title.setStyle(.sectionTitle)
        title.text = txt
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)
        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -25)
        ])
        return section
    }
}

extension ReceiveViewController: DialogEditViewControllerDelegate {

    func didSave(_ note: String) {
        viewModel.description = note
        newAddress()
    }

    func didClose() { }
}

extension ReceiveViewController: LTSuccessViewControllerDelegate {
    func onDone() {
        print("Done")
    }
}

extension ReceiveViewController: AmountCellDelegate {

    func onInputDenomination() {
        showDialogInputDenominations()
    }

    func onFeeInfo() {
        showLightningFeeInfo()
    }

    func textFieldEnabled() {
        lightningAmountEditing = true
        reload()
    }

    func textFieldDidChange(_ satoshi: Int64?, isFiat: Bool) {
        viewModel.satoshi = satoshi
        viewModel.isFiat = isFiat
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    func stateDidChange(_ state: AmountCellState) {
        viewModel.state = state
        btnConfirm.isEnabled = viewModel.state == .valid || viewModel.state == .validFunding
        btnConfirm.setStyle( btnConfirm.isEnabled ? .primary : .primaryGray)
    }
}

extension ReceiveViewController: DialogInputDenominationViewControllerDelegate {

    func didSelectFiat() {
        viewModel.isFiat = true
        tableView.reloadData()
    }

    func didSelectInput(denomination: gdk.DenominationType) {
        viewModel.isFiat = false
        viewModel?.inputDenomination = denomination
        tableView.reloadData()
    }
}
extension ReceiveViewController: HWDialogConnectViewControllerDelegate {
    func connected() {
    }

    func logged() {
        Task { [weak self] in
            await self?.verifyAddress()
        }
    }

    func cancel() {
        error(HWError.Abort("id_cancel"))
    }

    func failure(err: Error) {
        error(err)
    }
}
extension ReceiveViewController: DialogAccountsViewControllerDelegate {
    func didSelectAccount(_ walletItem: gdk.WalletItem?) {
        if let account = walletItem {
            viewModel.account = account
            viewModel.type = account.gdkNetwork.lightning ? .bolt11 : .address
            reload()
            newAddress()
        }
    }
}
