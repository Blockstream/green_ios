import UIKit
import core

import BreezSDK
import lightning
import gdk
import greenaddress

enum AccountSection: Int, CaseIterable {
    case account
    case adding
    case disclose
    case sweep
    case inbound
    case assets
    case transaction
    case footer
}

protocol AccountViewControllerDelegate: AnyObject {
    func didArchiveAccount()
}

class AccountViewController: UIViewController {

    enum FooterType {
        case noTransactions
        case none
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var actionsBg: UIView!
    @IBOutlet weak var btnSend: UIButton!
    @IBOutlet weak var btnReceive: UIButton!
    @IBOutlet weak var btnScanView: UIView!
    @IBOutlet weak var divider: UIView!

    private var headerH: CGFloat = 54.0
    private var footerH: CGFloat = 54.0
    private var cardH: CGFloat = 64.0
    private var cardHc: CGFloat = 184.0

    weak var delegate: AccountViewControllerDelegate?
    var viewModel: AccountViewModel!

    private var sIdx: Int = 0
    private var notificationObservers: [NSObjectProtocol] = []
    private var isReloading = false
    private var hideBalance: Bool {
        return UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue)
    }
    private let drawerItem = ((Bundle.main.loadNibNamed("DrawerBarItem", owner: WalletViewController.self, options: nil)![0] as? DrawerBarItem)!)
    private var showScan = true

    override func viewDidLoad() {
        super.viewDidLoad()

        btnScanView.isHidden = !showScan
        divider.isHidden = showScan

        register()
        setContent()
        setStyle()
        tableView.selectRow(at: IndexPath(row: sIdx, section: AccountSection.account.rawValue), animated: false, scrollPosition: .none)
        AnalyticsManager.shared.recordView(.accountOverview, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setNavigationBar()
        reloadSections([AccountSection.assets, AccountSection.adding, AccountSection.disclose], animated: false)

        EventType.allCases.forEach {
            let observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: $0.rawValue),
                                                                  object: nil,
                                                                  queue: .main,
                                                                  using: { [weak self] notification in
                if let eventType = EventType(rawValue: notification.name.rawValue) {
                    self?.handleEvent(eventType, details: notification.userInfo ?? [:])
                }
            })
            notificationObservers.append(observer)
        }
        if URLSchemeManager.shared.isValid {
            if let bip21 = URLSchemeManager.shared.bip21 {
                let sendAddressInputViewModel = SendAddressInputViewModel(
                    input: bip21,
                    preferredAccount: viewModel.account,
                    txType: .transaction)
                presentSendAddressInputViewController(sendAddressInputViewModel)
                URLSchemeManager.shared.url = nil
            }
        }
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        drawerIcon(false)
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers = []
    }

    func reload() {
        if isReloading {
            return
        }
        isReloading = true
        if viewModel.paused {
            // avoid reload contents before session are valid
            return
        }
        Task.detached() { [weak self] in
            logger.info(">> getBalance")
            try? await self?.viewModel.getBalance()
            await self?.reloadSections([.disclose, .adding, .account, .assets], animated: true)
            logger.info(">> getCacheTransactions")
            await self?.viewModel.getCachedTransactions()
            let animatedTxs = await self?.viewModel.cachedTransactions.isEmpty ?? true
            await self?.reloadSections([.transaction], animated: animatedTxs)
            logger.info(">> getTransactions")
            let refresh = try? await self?.viewModel.getTransactions()
            if refresh ?? true {
                let animatedTxs = await self?.viewModel.cachedTransactions.isEmpty ?? true
                await self?.reloadSections([.transaction], animated: animatedTxs)
            }
            logger.info(">> updateNodeInfo")
            if await self?.viewModel.isLightning ?? false {
                _ = await self?.viewModel.account.lightningSession?.lightBridge?.updateNodeInfo()
                await self?.reloadSections([.sweep, .inbound], animated: true)
            }
            logger.info(">> MainActor")
            await MainActor.run { [weak self] in
                self?.isReloading = false
            }
        }
    }

    @MainActor
    func reloadSections(_ sections: [AccountSection], animated: Bool) {
        if animated {
            self.tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                self.tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
        if sections.contains(AccountSection.account) {
            self.tableView.selectRow(at: IndexPath(row: self.sIdx, section: AccountSection.account.rawValue), animated: false, scrollPosition: .none)
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            self.tableView.refreshControl?.endRefreshing()
        }
    }

    func register() {
        ["AccountCell", "WalletAssetCell", "TransactionCell",
         "AddingCell", "DiscloseCell", "LTInboundCell", "LTSweepCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    func setNavigationBar() {
        navigationItem.rightBarButtonItems = []
        // setup right menu bar: settings
        let settingsBtn = UIButton(type: .system)
        settingsBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        settingsBtn.setImage(UIImage(named: "ic_gear"), for: .normal)
        settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        if !viewModel.watchOnly {
            navigationItem.rightBarButtonItems?.append( UIBarButtonItem(customView: settingsBtn) )
        }
        let ampHelpBtn = UIButton(type: .system)
        ampHelpBtn.setImage(UIImage(named: "ic_help"), for: .normal)
        ampHelpBtn.addTarget(self, action: #selector(ampHelp), for: .touchUpInside)
        if viewModel.ampEducationalMode == .header {
            navigationItem.rightBarButtonItems?.append( UIBarButtonItem(customView: ampHelpBtn) )
        }
        if AccountsRepository.shared.current?.isDerivedLightning ?? false {
            drawerIcon(true)
            let leftItem: UIBarButtonItem = UIBarButtonItem(customView: drawerItem)
            navigationItem.leftBarButtonItem = leftItem
            let desiredWidth = 135.0
            let desiredHeight = 35.0
            let widthConstraint = NSLayoutConstraint(item: drawerItem, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: desiredWidth)
            let heightConstraint = NSLayoutConstraint(item: drawerItem, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: desiredHeight)
            drawerItem.addConstraints([widthConstraint, heightConstraint])
        }
    }

    func setActionBar() {
        btnSend.setTitle( "id_send".localized, for: .normal )
        btnReceive.setTitle( "id_receive".localized, for: .normal )
        // Sweep is only supported in watch-only for btc multisig wallets
        if viewModel.watchOnly {
            if let account = AccountsRepository.shared.current, !account.gdkNetwork.liquid {
                   btnSend.setTitle( "id_sweep".localized, for: .normal )
                   btnSend.setImage(UIImage(named: "qr_sweep"), for: .normal)
               } else {
                   btnSend.isEnabled = false
                   btnSend.setTitleColor(.white.withAlphaComponent(0.5), for: .normal)
               }
        }
    }

    func setContent() {

        setActionBar()
        tableView.prefetchDataSource = self
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(callPullToRefresh(_:)), for: .valueChanged)
        drawerItem.configure(img: viewModel.headerIcon, onTap: {[weak self] () in
                self?.switchNetwork()
        })
    }

    // open wallet selector drawer
    @objc func switchNetwork() {
        let storyboard = UIStoryboard(name: "DrawerNetworkSelection", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DrawerNetworkSelection") as? DrawerNetworkSelectionViewController {
            vc.transitioningDelegate = self
            vc.modalPresentationStyle = .custom
            vc.delegate = self
            present(vc, animated: true, completion: nil)
        }
    }

    func setStyle() {
        actionsBg.layer.cornerRadius = 5.0
        btnScanView.layer.cornerRadius = 10.0
    }

    func drawerIcon(_ show: Bool) {
        if let bar = navigationController?.navigationBar {
            if show {
                let i = UIImageView(frame: CGRect(x: 0.0, y: bar.frame.height / 2.0 - 5.0, width: 7.0, height: 10.0))
                i.image = UIImage(named: "ic_drawer")
                i.tag = 999
                bar.addSubview(i)
            } else {
                bar.subviews.forEach { if $0.tag == 999 { $0.removeFromSuperview()} }
            }
        }
    }

    // tableview refresh gesture
    @objc func callPullToRefresh(_ sender: UIRefreshControl? = nil) {
        reload()
    }

    // open settings
    @objc func settingsBtnTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel =  DialogListViewModel(
                title: "Account Preferences",
                type: .accountPrefs,
                items: viewModel.accountSettingsCell())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func twoFactorAuthenticatorDialog() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "id_enable_2fa".localized, type: .enable2faPrefs, items: Enable2faPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    // open receive screen
    func receiveScreen() {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController {
            guard let account = viewModel.account else { return }
            vc.viewModel = ReceiveViewModel(account: account,
                                            accounts: [account])
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func renameDialog() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogRenameViewController") as? DialogRenameViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.isAccountRename = true
            vc.delegate = self
            vc.index = nil
            vc.prefill = viewModel.account.localizedName
            present(vc, animated: false, completion: nil)
        }
    }

    func rename(name: String) {
        Task {
            do {
                startLoader()
                try await viewModel.renameSubaccount(name: name)
                stopLoader()
                reloadSections([.account], animated: true)
            } catch { showError(error) }
        }
    }

    func removeSubaccount() {
        Task {
            do {
                startLoader()
                try await viewModel.removeLightningSubaccount()
                stopLoader()
                delegate?.didArchiveAccount()
                await MainActor.run { navigationController?.popViewController(animated: true) }
            } catch { showError(error) }
        }
    }

    func logout() {
        Task {
            let account = AccountsRepository.shared.current
            await WalletManager.current?.disconnect()
            WalletsRepository.shared.delete(for: account?.id ?? "")
            AccountNavigator.goLogout(account: nil)
        }
    }

    func archive() {
        Task {
            do {
                startLoader(message: "Archiving")
                try await viewModel.archiveSubaccount()
                stopLoader()
                delegate?.didArchiveAccount()
                showDialog()
            } catch { showError(error) }
        }
    }

    @MainActor
    func showDialog() {
        let storyboard = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountArchivedViewController") as? AccountArchivedViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    func navigateTo2fa(_ account: WalletItem) {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TwoFactorAuthenticationViewController") as? TwoFactorAuthenticationViewController {
            vc.showBitcoin = !account.gdkNetwork.liquid
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func navigateToBip85Mnemonic() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "OnBoardInfoViewController") as? OnBoardInfoViewController {
            vc.isSettingDisplay = true
            vc.showBip85 = true
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func presentNodeInfo() {
        guard let lightningSession = viewModel.account.lightningSession else { return }
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogNodeViewController") as? DialogNodeViewController {
            vc.viewModel = DialogNodeViewModel(lightningSession: lightningSession)
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func showExperimental() {
        let ltFlow = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = ltFlow.instantiateViewController(withIdentifier: "LTExperimentalViewController") as? LTExperimentalViewController {
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    func handleShortcut(isOn: Bool) {
        Task {
            if isOn {
                try? await viewModel.addLightningShortcut()
            }
            presentLTShortcutViewController(isOn: isOn)
        }
    }

    @MainActor
    func presentLTShortcutViewController(isOn: Bool) {
        let storyboard = UIStoryboard(name: "LTShortcutFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTShortcutViewController") as? LTShortcutViewController,
           let account = WalletManager.current?.account {
            vc.vm = LTShortcutViewModel(account: account,
                                        action: isOn ? .addFromAccount : .remove)
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func presentLTShortcutViewController() {
        let storyboard = UIStoryboard(name: "LTShortcutFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTShortcutViewController") as? LTShortcutViewController, let account = WalletManager.current?.account {
            vc.vm = LTShortcutViewModel(account: account,
                                        action: .remove)
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @objc func ampHelp() {
        if let url = URL(string: "https://help.blockstream.com/hc/en-us/articles/5301732614169-How-do-I-receive-AMP-assets-") {
            SafeNavigationManager.shared.navigate(url)
        }
    }

    func onInboundInfo() {
        SafeNavigationManager.shared.navigate( ExternalUrls.helpReceiveCapacity )
    }

    func presentDialogDetailViewController(_ model: WalletAssetCellModel) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogDetailViewController") as? DialogDetailViewController {
            vc.asset = model.asset
            vc.tag = model.asset?.assetId ?? ""
            vc.satoshi = model.satoshi
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func pushTransactionViewController(_ tx: Transaction) {

        let storyboard = UIStoryboard(name: "TxDetails", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TxDetailsViewController") as? TxDetailsViewController, let wallet = tx.subaccountItem {
            vc.vm = TxDetailsViewModel(wallet: wallet, transaction: tx)
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }

//        let storyboard = UIStoryboard(name: "Transaction", bundle: nil)
//        if let vc = storyboard.instantiateViewController(withIdentifier: "TransactionViewController") as? TransactionViewController {
//            vc.transaction = tx
//            vc.wallet = tx.subaccountItem
//            vc.delegate = self
//            navigationController?.pushViewController(vc, animated: true)
//        }
    }

    @IBAction func btnSend(_ sender: Any) {
        let sendAddressInputViewModel = SendAddressInputViewModel(
            input: nil,
            preferredAccount: viewModel.account,
            txType: viewModel.watchOnly ? .sweep : .transaction)
        self.presentSendAddressInputViewController(sendAddressInputViewModel)
    }

    @IBAction func btnReceive(_ sender: Any) {
        receiveScreen()
    }

    @IBAction func btnQr(_ sender: Any) {
        if let vc = DialogScanViewController.vc {
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    func handleEvent(_ eventType: EventType, details: [AnyHashable: Any]) {
        switch eventType {
        case .Transaction, .InvoicePaid, .PaymentFailed, .PaymentSucceed:
            reload()
        case .Block:
            if viewModel.cachedTransactions.filter({ $0.blockHeight == 0 }).first != nil {
                reload()
            }
        case .AssetsUpdated:
            reload()
        case .Network:
            if let details = details as? [String: Any],
               let connection = Connection.from(details) as? Connection {
                if connection.connected {
                    reload()
                }
            }
        case .Settings, .Ticker, .TwoFactorReset:
            reload()
        case .bip21Scheme:
            if URLSchemeManager.shared.isValid {
                if let bip21 = URLSchemeManager.shared.bip21 {
                    let sendAddressInputViewModel = SendAddressInputViewModel(
                        input: bip21,
                        preferredAccount: viewModel.account,
                        txType: .transaction)
                    presentSendAddressInputViewController(sendAddressInputViewModel)
                    URLSchemeManager.shared.url = nil
                }
            }
        default:
            break
        }
    }
}

extension AccountViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return AccountSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch AccountSection(rawValue: section) {
        case .account:
            return viewModel.accountCellModels.count
        case .adding:
            return viewModel.addingCellModels.count
        case .disclose:
            return viewModel.discloseCellModels.count
        case .sweep:
            return viewModel.sweepCellModels.count
        case .inbound:
            return viewModel.inboundCellModels.count
        case .assets:
            return viewModel.showAssets ? viewModel.assetCellModels.count : 0
        case .transaction:
            return viewModel.txCellModels.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch AccountSection(rawValue: indexPath.section) {
        case .account:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AccountCell.identifier, for: indexPath) as? AccountCell {
                let model = viewModel.accountCellModels[indexPath.row]

                let onCopy: (() -> Void)? = {
                    UIPasteboard.general.string = model.account.receivingId
                    DropAlert().info(message: NSLocalizedString("id_copied_to_clipboard", comment: ""), delay: 2.0)
                }
                cell.configure(model: model,
                               cIdx: indexPath.row,
                               sIdx: sIdx,
                               hideBalance: hideBalance,
                               isLast: true,
                               onSelect: nil,
                               onCopy: onCopy,
                               onShield: nil,
                               onExperiental: {[weak self] in self?.showExperimental()})
                cell.selectionStyle = .none
                return cell
            }
        case .adding:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AddingCell.identifier, for: indexPath) as? AddingCell {
                cell.configure(model: viewModel.addingCellModels[indexPath.row])
                cell.selectionStyle = .none
                return cell
            }
        case .disclose:
            if let cell = tableView.dequeueReusableCell(withIdentifier: DiscloseCell.identifier, for: indexPath) as? DiscloseCell {
                cell.configure(model: viewModel.discloseCellModels[indexPath.row])
                cell.selectionStyle = .none
                return cell
            }
        case .sweep:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTSweepCell.identifier, for: indexPath) as? LTSweepCell {
                cell.configure(model: viewModel.sweepCellModels[indexPath.row], onInfo: { [weak self] in
                    if let self = self {
                        self.pushLTRecoverFundsViewController(self.viewModel.ltRecoverFundsViewModelSweep())
                    }
                })
                cell.selectionStyle = .none
                return cell
            }
        case .inbound:
            if let cell = tableView.dequeueReusableCell(withIdentifier: LTInboundCell.identifier, for: indexPath) as? LTInboundCell {
                cell.configure(model: viewModel.inboundCellModels[indexPath.row], onInboundInfo: { [weak self] in
                    self?.onInboundInfo()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .assets:
            if let cell = tableView.dequeueReusableCell(withIdentifier: WalletAssetCell.identifier, for: indexPath) as? WalletAssetCell {
                cell.configure(model: viewModel.assetCellModels[indexPath.row], hideBalance: hideBalance)
                cell.selectionStyle = .none
                return cell
            }
        case .transaction:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.identifier, for: indexPath) as? TransactionCell {
                cell.configure(model: viewModel.txCellModels[indexPath.row], hideBalance: hideBalance)
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func pushLTRecoverFundsViewController(_ model: LTRecoverFundsViewModel) {
        let ltFlow = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = ltFlow.instantiateViewController(withIdentifier: "LTRecoverFundsViewController") as? LTRecoverFundsViewController {
            vc.viewModel = model
            vc.modalPresentationStyle = .overFullScreen
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch AccountSection(rawValue: section) {
        case .transaction: // , .assets:
            return headerH
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch AccountSection(rawValue: section) {
        case .transaction:
            return viewModel.txCellModels.count == 0 ? footerH : 1.0
        case .footer:
            return 100.0
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        switch AccountSection(rawValue: indexPath.section) {
        case .account:
            return indexPath.row == sIdx ? cardHc : cardH
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch AccountSection(rawValue: section) {
        case .transaction:
            return headerView("id_latest_transactions".localized)
        case .assets:
            return nil // headerView( "Balance" )
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch AccountSection(rawValue: section) {
        case .transaction:
            return viewModel.txCellModels.count == 0 ? footerView(.noTransactions) : footerView(.none)
        default:
            return footerView(.none)
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch AccountSection(rawValue: indexPath.section) {
        case .account:
            return nil
        default:
            return indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch AccountSection(rawValue: indexPath.section) {
        case .account:
            break
        case .adding:
            twoFactorAuthenticatorDialog()
        case .disclose:
            ampHelp()
        case .inbound:
            break
        case .assets:
            if let assetModel = viewModel?.assetCellModels[indexPath.row] {
                presentDialogDetailViewController(assetModel)
            }
        case .transaction:
            if let tx = viewModel?.txCellModels[indexPath.row].tx {
                if tx.isLightningSwap ?? false {
                    if tx.isInProgressSwap ?? false {
                        DropAlert().warning(message: "Swap in progress")
                    } else {
                        pushTransactionViewController(tx)
                    }
                } else {
                    pushTransactionViewController(tx)
                }
            }
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: false)
        tableView.selectRow(at: IndexPath(row: sIdx, section: AccountSection.account.rawValue), animated: false, scrollPosition: .none)
    }
}

extension AccountViewController: UITableViewDataSourcePrefetching {
   // incremental transactions fetching from gdk
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        let filteredIndexPaths = indexPaths.filter { $0.section == AccountSection.transaction.rawValue }
        let row = filteredIndexPaths.last?.row ?? 0
        if viewModel.page > 0 && row > (viewModel.txCellModels.count - 3) {
            Task.detached { [weak self] in
                await self?.getTransactions()
            }
        }
    }

    func getTransactions() async {
        let refresh = try? await viewModel.getTransactions(restart: false, max: nil)
        if refresh ?? true {
            reloadSections([.transaction], animated: false)
        }
    }
}

extension AccountViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }
}

extension AccountViewController {

    func headerView(_ txt: String) -> UIView {

        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.font = .systemFont(ofSize: 18.0, weight: .heavy)
        title.text = txt
        title.textColor = .white
        title.numberOfLines = 0

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 10.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 20)
        ])

        return section
    }

    func footerView(_ type: FooterType) -> UIView {

        switch type {
        case .none:
            let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 1.0))
            section.backgroundColor = .clear
            return section
        case .noTransactions:
            let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: footerH))
            section.backgroundColor = .clear

            let lblNoTransactions = UILabel(frame: .zero)
            lblNoTransactions.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            lblNoTransactions.textColor = UIColor.gGrayTxt()
            lblNoTransactions.numberOfLines = 0
            lblNoTransactions.text = NSLocalizedString("id_your_transactions_will_be_shown", comment: "")
            lblNoTransactions.translatesAutoresizingMaskIntoConstraints = false
            section.addSubview(lblNoTransactions)

            var padding: CGFloat = 50.0
            lblNoTransactions.textAlignment = .left

            if !viewModel.fetchingTxs {
                padding = 25.0
            }

            NSLayoutConstraint.activate([
                lblNoTransactions.topAnchor.constraint(equalTo: section.topAnchor, constant: 0.0),
                lblNoTransactions.bottomAnchor.constraint(equalTo: section.bottomAnchor, constant: 0.0),
                lblNoTransactions.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: padding),
                lblNoTransactions.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 0.0)
            ])

            if viewModel.fetchingTxs {
                let loader = UIActivityIndicatorView(style: .white)
                section.addSubview(loader)
                loader.startAnimating()
                loader.translatesAutoresizingMaskIntoConstraints = false
                let horizontalConstraint = NSLayoutConstraint(item: loader,
                                                              attribute: .left,
                                                              relatedBy: .equal,
                                                              toItem: section,
                                                              attribute: .left,
                                                              multiplier: 1,
                                                              constant: 20.0)
                let verticalConstraint = NSLayoutConstraint(item: loader,
                                                            attribute: .centerY,
                                                            relatedBy: .equal,
                                                            toItem: lblNoTransactions,
                                                            attribute: .centerY,
                                                            multiplier: 1,
                                                            constant: 0)
                NSLayoutConstraint.activate([horizontalConstraint, verticalConstraint])
            }
            return section
        }

    }
}

extension AccountViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {
        switch type {
        case .accountPrefs:
            if let item = viewModel.accountSettingsPrefs()[safe: index] {
                switch item {
                case .shortcut:
                    if isOn == false {
                        let storyboard = UIStoryboard(name: "LTShortcutFlow", bundle: nil)
                        if let vc = storyboard.instantiateViewController(withIdentifier: "LTRemoveShortcutViewController") as? LTRemoveShortcutViewController {
                            vc.modalPresentationStyle = .overFullScreen
                            vc.delegate = self
                            // rvc.account = account
                            present(vc, animated: false, completion: nil)
                        }
                    } else {
                        handleShortcut(isOn: isOn)
                    }
                default:
                    break
                }
            } else {
                switch index {
                case 0:
                    presentNodeInfo()
                case 1:
                    removeSubaccount()
                default:
                    break
                }
            }
        default:
            break
        }
    }

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .accountPrefs:
            if let item = viewModel.accountSettingsPrefs()[safe: index] {
                switch item {
                case .rename:
                    renameDialog()
                case .archive:
                    archive()
                case .enhanceSecurity:
                    break
                case .nodeInfo:
                    presentNodeInfo()
                case .remove:
                    removeSubaccount()
                case .shortcut:
                    break
                case .logout:
                    logout()
                case .settings:
                    settings()
                }
            }
        case .enable2faPrefs:
            switch Enable2faPrefs(rawValue: index) {
            case .add:
                let session = viewModel.account.session
                let enabled2FA = session?.twoFactorConfig?.anyEnabled ?? false
                let isSS = session?.gdkNetwork.electrum ?? false
                if isSS {
                    showError("Two-Factor authentication not available for singlesig accounts")
                    return
                } else if enabled2FA {
                    showError("Two factor authentication already enabled")
                    return
                }
                navigateTo2fa(viewModel.account)
            default:
                break
            }
        default:
            break
        }
    }
    func settings() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let nvc = storyboard.instantiateViewController(withIdentifier: "UserSettingsNavigationController")
        if let nvc = nvc as? UINavigationController {
            if let vc = nvc.viewControllers.first as? UserSettingsViewController {
                vc.delegate = self
                nvc.modalPresentationStyle = .fullScreen
                present(nvc, animated: true, completion: nil)
            }
        }
    }
}

extension AccountViewController: DialogRenameViewControllerDelegate {
    func didRename(name: String, index: String?) {
        rename(name: name)
    }
    func didCancel() {
    }
}

extension AccountViewController: TxDetailsViewControllerDelegate {
    func onMemoEdit() {
        reload()
    }
}

extension AccountViewController: AccountArchivedViewControllerDelegate {
    func onDismissArchived() {
        self.navigationController?.popViewController(animated: true)
    }

    func showArchived() {
        let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountArchiveViewController") as? AccountArchiveViewController, var viewControllers = navigationController?.viewControllers, let nav = navigationController {
            viewControllers.removeLast()
            viewControllers.append(vc)
            nav.setViewControllers(viewControllers, animated: true)
        }
    }
}

extension AccountViewController: DialogScanViewControllerDelegate {

    func didScan(value: ScanResult, index: Int?) {
        let account = viewModel.accountCellModels[sIdx].account
        let sendAddressInputViewModel = SendAddressInputViewModel(
            input: value.result,
            preferredAccount: account,
            txType: nil)
        presentSendAddressInputViewController(sendAddressInputViewModel)
    }

    func sendViewController() {
        if viewModel.satoshi == 0 {
            let alert = UIAlertController(title: "id_warning".localized,
                                          message: "id_you_have_no_coins_to_send".localized,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { _ in  })
            alert.addAction(UIAlertAction(title: "id_receive".localized, style: .default) { _ in self.receiveScreen() })
            present(alert, animated: true, completion: nil)
            return
        }
        let sendAddressInputViewModel = SendAddressInputViewModel(preferredAccount: viewModel.account, txType: .transaction)
        presentSendAddressInputViewController(sendAddressInputViewModel)
    }
    
    func presentSendAddressInputViewController(_ sendAddressInputViewModel: SendAddressInputViewModel) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAddressInputViewController") as? SendAddressInputViewController {
            vc.viewModel = sendAddressInputViewModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func didStop() {
    }
}
extension AccountViewController: DialogNodeViewControllerProtocol {

    func navigateMnemonic() {
        navigateToBip85Mnemonic()
    }

    func onSendAll() {
        pushLTRecoverFundsViewController(viewModel.ltRecoverFundsViewModelSendAll())
    }

    @MainActor
    func presentAlertClosedChannels() {
        let viewModel = AlertViewModel(title: "id_close_channel".localized, hint: "id_channel_closure_initiated_you".localized)
        let storyboard = UIStoryboard(name: "Alert", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as? AlertViewController {
            vc.viewModel = viewModel
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
}

extension AccountViewController: AlertViewControllerDelegate {
    func onAlertOk() {
        reload()
    }
}

extension AccountViewController: LTShortcutViewControllerDelegate {
    func onTap(_ action: LTShortcutUserAction) {
        switch action {
        case .learnMore:
            print("learnMore")
        case .done:
            print("Done")
        case .remove:
            print("Remove")
            Task { try? await viewModel.removeLightningShortcut() }
        }
    }
}

extension AccountViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        if let presented = presented as? DrawerNetworkSelectionViewController {
            return DrawerPresentationController(presentedViewController: presented, presenting: presenting)
        }
        return ModalPresentationController(presentedViewController: presented, presenting: presenting)
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if presented as? DrawerNetworkSelectionViewController != nil {
            return DrawerAnimator(isPresenting: true)
        } else {
            return ModalAnimator(isPresenting: true)
        }
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if dismissed as? DrawerNetworkSelectionViewController != nil {
            return DrawerAnimator(isPresenting: false)
        } else {
            return ModalAnimator(isPresenting: false)
        }
    }
}

extension AccountViewController: DrawerNetworkSelectionDelegate {

    // accounts drawer: add new waller
    func didSelectAddWallet() {
        AccountNavigator.goAddWallet(nv: navigationController)
    }

    // accounts drawer: select another account
    func didSelectAccount(account: Account) {
        // don't switch if same account selected
        if account.id == viewModel.wm?.account.id {
            return
        } else if let wm = WalletsRepository.shared.get(for: account.id), wm.logged {
            AccountNavigator.goLogged(account: account)
        } else {
            AccountNavigator.goLogin(account: account)
        }
    }

    // accounts drawer: select app settings
    func didSelectSettings() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }

    func didSelectAbout() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAboutViewController") as? DialogAboutViewController {
                vc.modalPresentationStyle = .overFullScreen
                self.present(vc, animated: false, completion: nil)
            }
        })
    }
}

extension AccountViewController: UserSettingsViewControllerDelegate {
    func userLogout() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            if AppSettings.shared.gdkSettings?.tor ?? false {
                self.startLoader(message: "id_logout".localized)
            }
            Task {
                let account = self.viewModel.wm?.account
                if account?.isHW ?? false {
                    try? await BleViewModel.shared.disconnect()
                }
                await WalletManager.current?.disconnect()
                WalletsRepository.shared.delete(for: account?.id ?? "")
                AccountNavigator.goLogout(account: nil)
                self.stopLoader()
            }
        })
    }

    func refresh() {
        reload()
    }
}

extension AccountViewController: LTRemoveShortcutViewControllerDelegate {
    func onCancel() {
        //
    }
    func onRemove(_ index: String?) {
        handleShortcut(isOn: false)
    }
}
