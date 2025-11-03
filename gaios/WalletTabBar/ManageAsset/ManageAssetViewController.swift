import UIKit
import gdk
import core

enum ManageAseetSection: Int, CaseIterable {
    case assetBalance
    case actions
    case accounts
    case transactions
}

class ManageAssetViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView?
    private var notificationObservers: [NSObjectProtocol] = []
    var viewModel: ManageAssetViewModel!
    var sectionHeaderH: CGFloat = 54.0
    var footerH: CGFloat = 54.0
    var isReloading = false

    var sections: [ManageAseetSection] {
        if viewModel.account == nil {
            return [.assetBalance, .accounts]
        } else {
            return [.assetBalance, .actions, .transactions]
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
        setupNotifications()
        Task { [weak self] in
            await self?.reload(discovery: false)
        }
        if viewModel.account != nil {
            loadNavigationBtns()
        }
        tableView?.refreshControl = UIRefreshControl()
        tableView?.refreshControl!.tintColor = UIColor.white
        tableView?.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if viewModel.account == nil {
            // required to refresh after renaming
            tableView?.reloadData()
        }
    }
    deinit {
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers = []
    }
    func setContent() {
        if viewModel.account != nil, viewModel.accounts().count > 1 {
            title = viewModel.account?.localizedName
        }
        if viewModel.account == nil {
            let asset = WalletManager.current?.info(for: viewModel.assetId)
            let name = asset?.name ?? asset?.assetId
            title = name
        }
    }

    func register() {
        ["AssetBalanceCell", "TransactActionsCell", "TransactionCell", "DialogAccountCell"].forEach {
            tableView?.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        settingsBtn.setImage(UIImage(named: "ic_nav_disclose"), for: .normal)
        settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: settingsBtn)]
    }
    @objc func pull(_ sender: UIRefreshControl? = nil) {
        Task.detached { [weak self] in
            await self?.reload(discovery: false)
            await MainActor.run { [weak self] in
                self?.tableView?.refreshControl?.endRefreshing()
            }
        }
    }
    @objc func settingsBtnTapped() {
        if viewModel.account?.isLightning ?? false {
            openLTSettingsViewController()
            return
        }
        var actions: [AccountSettingsType] = []
        if !(WalletManager.current?.isWatchonly ?? false) {
            actions.append(.rename(current: viewModel.account?.localizedName ?? ""))
        }
        actions.append(.watchonly)
        actions.append(.archive)
        let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountSettingsViewController") as? AccountSettingsViewController {
            vc.viewModel = AccountSettingsViewModel(title: "id_account_settings".localized, actions: actions, isFunded: viewModel.isFunded == true)
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    func receive() {
        receiveScreen()
    }
    func buy() {
        buyScreen()
    }
    func send() {
        sendScreen()
    }
    func onTxTap(_ indexPath: IndexPath) {
        let tx = viewModel.txCellModels[indexPath.row].tx
        if tx.isMeldPayment ?? false {
            // nothing
        } else if tx.isLightningSwap ?? false {
            if tx.isInProgressSwap ?? false {
                DropAlert().warning(message: "id_swap_is_in_progress".localized)
            } else {
                txScreen(tx)
            }
        } else {
            txScreen(tx)
        }
    }
    func onAccountTap(_ indexPath: IndexPath) {
        if let model = viewModel?.accountCellModels[indexPath.row],
           let assetId = model.assetId {
            let storyboard = UIStoryboard(name: "ManageAsset", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "ManageAssetViewController") as? ManageAssetViewController {
                vc.viewModel = ManageAssetViewModel(assetId: assetId,
                                                    account: model.account,
                                                    walletModel: self.viewModel.walletModel)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    func reload(discovery: Bool) async {
        if viewModel.paused {
            return
        }
        if isReloading {
            return
        }
        isReloading = true
        try? await self.viewModel.fetchBalances()
        reloadSections([.assetBalance], animated: false)
        if viewModel.account != nil {
            _ = try? await viewModel.fetchTransactions()
        }
        isReloading = false
        self.tableView?.reloadData()
    }
    @MainActor
    func reloadSections(_ sections: [ManageAseetSection], animated: Bool) {
        if animated {
            tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .fade)
        } else {
            UIView.performWithoutAnimation {
                tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }
    func handleEvent(_ eventType: EventType, details: [AnyHashable: Any]) {
        switch eventType {
        case .Transaction, .InvoicePaid, .PaymentFailed, .PaymentSucceed, .newSubaccount:
            Task.detached { [weak self] in
                await self?.reload(discovery: false)
            }
        case .Block:
            if viewModel.existPendingTransaction() {
                Task.detached { [weak self] in
                    await self?.reload(discovery: false)
                }
            }
        case .Settings:
            break
        case .AssetsUpdated, .Network, .Ticker, .TwoFactorReset:
            break
        default:
            break
        }
    }
    func setupNotifications() {
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: UIApplication.shared,
            queue: .main,
            using: { [weak self] _ in
                self?.handleForegroundEvent()
            })
        notificationObservers.append(observer)
        EventType.allCases.forEach {
            let observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name(rawValue: $0.rawValue),
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let eventType = EventType(rawValue: notification.name.rawValue) {
                        self?.handleEvent(eventType, details: notification.userInfo ?? [:])
                    }
                })
            notificationObservers.append(observer)
        }
    }
    func handleForegroundEvent() {
        Task.detached { [weak self] in
            await self?.reload(discovery: false)
        }
    }
    func accountRename(_ name: String) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogRenameViewController") as? DialogRenameViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.isAccountRename = true
            vc.delegate = self
            vc.prefill = name
            present(vc, animated: false, completion: nil)
        }
    }
    func showDescriptor() {
        let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountDescriptorViewController") as? AccountDescriptorViewController, let account = viewModel.account {
            vc.viewModel = AccountDescriptorViewModel(account: account)
            // vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func rename(_ name: String) {
        Task {
            do {
                startLoader(message: "id_renaming".localized)
                try await viewModel.renameSubaccount(name: name)
                stopLoader()
                setContent()
            } catch { showError(error) }
        }
    }
    func archive() {
        Task {
            do {
                startLoader(message: "id_archiving".localized)
                try await viewModel.archiveSubaccount()
                stopLoader()
//                delegate?.didArchiveAccount()
                showArchivedSuccess()
            } catch { showError(error) }
        }
    }
    @MainActor
    func showArchivedSuccess() {
        let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountArchivedViewController") as? AccountArchivedViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    func openLTSettingsViewController() {
        guard let lightningSession = viewModel.wm?.lightningSession else {
            DropAlert().warning(message: "Create a lightning account")
            return
        }
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTSettingsViewController") as? LTSettingsViewController {
            vc.viewModel = LTSettingsViewModel(lightningSession: lightningSession, hideActions: true)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
extension ManageAssetViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch sections[section] {
        case .assetBalance:
            return 1
        case .actions:
            return 1
        case .accounts:
            return viewModel.accountCellModels.count
        case .transactions:
            return viewModel.txCellModels.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch sections[indexPath.section] {
        case .assetBalance:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AssetBalanceCell.identifier, for: indexPath) as? AssetBalanceCell {
                cell.configure(assetId: viewModel.assetId,
                               satoshi: viewModel.satoshi,
                               hideBalance: viewModel.hideBalance)
                cell.selectionStyle = .none
                return cell
            }
        case .actions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactActionsCell.identifier, for: indexPath) as? TransactActionsCell {
                let onBuy: (() -> Void)? = viewModel.isBTCAsset ? { [weak self] in
                    self?.buy()
                } : nil
                cell.configure(onBuy: onBuy, onSend: {[weak self] in
                    self?.send()
                }, onReceive: {[weak self] in
                    self?.receive()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .accounts:
            if let cell = tableView.dequeueReusableCell(withIdentifier: DialogAccountCell.identifier, for: indexPath) as? DialogAccountCell, let model = viewModel?.accountCellModels[indexPath.row] {
                cell.configure(
                    model: model,
                    isSelectable: true,
                    hideBalance: viewModel?.hideBalance ?? false,
                    onTap: {[weak self] in
                        self?.onAccountTap(indexPath)
                    })
                cell.selectionStyle = .none
                return cell
            }
        case .transactions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.identifier, for: indexPath) as? TransactionCell {
                cell.configure(model: viewModel.txCellModels[indexPath.row], hideBalance: viewModel.hideBalance, onTap: {[weak self] in
                    self?.onTxTap(indexPath)
                })
                cell.selectionStyle = .none
                return cell
            }
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sections[section] {
        case .transactions:
            return sectionHeaderH
        case .accounts:
            return viewModel.accountCellModels.count > 0 ? sectionHeaderH : 0.1
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch sections[section] {
        case .transactions:
            if viewModel.txCellModels.count == 0 && !isReloading {
                return footerH
            }
            return 0.1
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section] {
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch sections[section] {
        case .transactions:
            return sectionHeader("id_transactions".localized)
        case .accounts:
            return sectionHeader("id_accounts".localized)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch sections[section] {
        case .transactions:
            if viewModel.txCellModels.count == 0 && !isReloading {
                return sectionFooter("id_you_dont_have_any_transactions".localized)
            }
            return nil
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch sections[indexPath.section] {
        case .transactions:
            return indexPath
        case .assetBalance:
            return indexPath
        default:
            return nil // indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        default:
            break
        }
    }
}
extension ManageAssetViewController {
    func sectionHeader(_ txt: String) -> UIView {

        guard let tView = tableView else { return UIView(frame: .zero) }
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tView.frame.width, height: sectionHeaderH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.setStyle(.txtSectionHeader)
        title.text = txt
        title.textColor = UIColor.gGrayTxt()
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
    func sectionFooter(_ txt: String) -> UIView {

        guard let tView = tableView else { return UIView(frame: .zero) }
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tView.frame.width, height: sectionHeaderH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.setStyle(.txtCard)
        title.text = txt
        title.textColor = UIColor.gGrayTxt()
        title.numberOfLines = 0
        title.textAlignment = .center

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 0.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -25)
        ])

        return section
    }
}

extension ManageAssetViewController {

    func buyScreen() {
        AnalyticsManager.shared.buyInitiate(account: AccountsRepository.shared.current)
        if !getCountlyRemoteConfigEnableBuyIosUk() && checkUKRegion() {
            showAlert(title: "id_buy_bitcoin".localized, message: "id_feature_unavailable_in_the_uk".localized)
            return
        }
        if getBitcoinSubaccounts().isEmpty {
            showAlert(title: "id_buy_bitcoin".localized, message: "id_feature_unavailable_for_liquid".localized)
            return
        }
        let storyboard = UIStoryboard(name: "BuyBTCFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "BuyBTCViewController") as? BuyBTCViewController {
            vc.viewModel = BuyBTCViewModel(
                account: viewModel.account,
                currency: viewModel.currency,
                hideBalance: viewModel.hideBalance)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func sendScreen() {
        let sendAddressInputViewModel = SendAddressInputViewModel(
            input: nil,
            preferredAccount: viewModel.account,
            txType: nil,
            assetId: viewModel.assetId)

        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAddressInputViewController") as? SendAddressInputViewController {
            vc.viewModel = sendAddressInputViewModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func txScreen(_ tx: Transaction) {
        let storyboard = UIStoryboard(name: "TxDetails", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TxDetailsViewController") as? TxDetailsViewController, let wallet = tx.subaccount {
            vc.vm = TxDetailsViewModel(wallet: wallet, transaction: tx)
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func receiveScreen() {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController, let account = viewModel.account {
            let waParam: (WalletItem, String) = (account, viewModel.assetId)
            vc.viewModel = ReceiveViewModel(waParam)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func accountsScreen(model: DialogAccountsViewModel) {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAccountsViewController") as? DialogAccountsViewController {
            vc.viewModel = model
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
    func checkUKRegion() -> Bool {
        return Locale.current.regionCode == "GB"
    }

    func getCountlyRemoteConfigEnableBuyIosUk() -> Bool {
        return AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigEnableBuyIosUk) as? Bool ?? false
    }

    func getBitcoinSubaccounts() -> [WalletItem] {
        WalletManager.current?.bitcoinSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    func openWatchOnly(session: SessionManager) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogWatchOnlySetUpViewController") as? DialogWatchOnlySetUpViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.session = session
            present(vc, animated: false, completion: nil)
        }
    }
}
extension ManageAssetViewController: TxDetailsViewControllerDelegate {
    func onMemoEdit() {
        Task { [weak self] in
            await self?.reload(discovery: false)
        }
    }
}
extension ManageAssetViewController: AccountSettingsViewControllerDelegate {
    func didSelectAction(_ type: AccountSettingsType) {
        switch type {
        case .rename(let current):
            accountRename(current)
        case .watchonly:
            if viewModel.account?.isSinglesig == true {
                showDescriptor()
            } else if viewModel.account?.isMultisig == true {
                if let network = viewModel.account?.network,
                   let session = viewModel.wm?.sessions[network] {
                    openWatchOnly(session: session)
                }
            }
        case .archive:
            archive()
        }
    }
}
extension ManageAssetViewController: DialogRenameViewControllerDelegate {
    func didRename(name: String, index: String?) {
        rename(name)
    }
    func didCancel() {}
}
extension ManageAssetViewController: AccountArchivedViewControllerDelegate {
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
extension ManageAssetViewController: DialogWatchOnlySetUpViewControllerDelegate {
    func watchOnlyDidUpdate(_ action: WatchOnlySetUpAction) {}
}
