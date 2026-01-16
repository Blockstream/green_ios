import UIKit
import gdk
import core

enum ManageAssetSection: Int, CaseIterable {
    case assetBalance
    case actions
    case cta
    case accounts
    case transactions
}

class ManageAssetViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView?
    let viewModel: ManageAssetViewModel

    init?(coder: NSCoder, viewModel: ManageAssetViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("You must create this view controller with a view model.")
    }

    var sectionHeaderH: CGFloat = 54.0
    var footerH: CGFloat = 54.0

    var sections: [ManageAssetSection] {
        if viewModel.selectedSubaccount == nil {
            return [.assetBalance, .accounts]
        } else {
            return [.assetBalance, .actions, .cta, .transactions]
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()
        tableView?.refreshControl = UIRefreshControl()
        tableView?.refreshControl!.tintColor = UIColor.white
        tableView?.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
        register()
        reloadTitle()
        reloadNavigation()
        viewModel.onUpdate = { [weak self] feature in
            DispatchQueue.main.async {
                self?.onUpdate(feature: feature)
            }
        }
    }
    func onUpdate(feature: RefreshFeature?) {
        switch feature {
        case .alertCards, .balance, .subaccounts, .nestedTxs(_, _):
            if tableView?.refreshControl?.isRefreshing == true {
                tableView?.refreshControl?.endRefreshing()
            }
            tableView?.reloadData()
            reloadTitle()
        default:
            break
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView?.reloadData()
        viewModel.refresh()
    }
    func reloadTitle() {
        if let subaccount = viewModel.selectedSubaccount {
            title = subaccount.localizedName
        } else {
            let asset = WalletManager.current?.info(for: viewModel.assetId)
            let name = asset?.name ?? asset?.assetId
            title = name
        }
    }

    func register() {
        ["AssetBalanceCell", "TransactActionsCell", "TransactionCell", "DialogAccountCell", "ActionCell"].forEach {
            tableView?.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    func reloadNavigation() {
        if viewModel.selectedSubaccount != nil {
            let settingsBtn = UIButton(type: .system)
            settingsBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
            settingsBtn.setImage(UIImage(named: "ic_nav_disclose"), for: .normal)
            settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
            navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: settingsBtn)]
        } else {
            navigationItem.rightBarButtonItems = []
        }
    }
    @objc func pull(_ sender: UIRefreshControl? = nil) {
        viewModel.refresh()
    }
    @objc func settingsBtnTapped() {
        guard let subaccount = viewModel.selectedSubaccount else { return }
        if subaccount.isLightning {
            openLTSettingsViewController()
            return
        }
        var actions: [AccountSettingsType] = []
        if !(WalletManager.current?.isWatchonly ?? false) {
            actions.append(.rename(current: subaccount.localizedName))
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
        guard let tx = viewModel.txs?[indexPath.row] else { return }
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
        let subaccount = viewModel.subaccounts[indexPath.row]
        let vm = ManageAssetViewModel(
            walletDataModel: viewModel.walletDataModel,
            wallet: viewModel.wallet,
            mainAccount: viewModel.mainAccount,
            assetId: viewModel.assetId,
            selectedSubaccount: subaccount
        )
        let storyboard = UIStoryboard(name: "ManageAsset", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "ManageAssetViewController") { coder in
            ManageAssetViewController(coder: coder, viewModel: vm)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @MainActor
    func reloadSections(_ sections: [ManageAssetSection], animated: Bool) {
        if animated {
            tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .fade)
        } else {
            UIView.performWithoutAnimation {
                tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
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
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountDescriptorViewController") as? AccountDescriptorViewController, let account = viewModel.selectedSubaccount {
            vc.viewModel = AccountDescriptorViewModel(account: account)
            // vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func rename(_ name: String) async {
        startLoader(message: "id_renaming".localized)
        let task = Task { try await viewModel.renameSubaccount(name: name) }
        switch await task.result {
        case .success:
            stopLoader()
            viewModel.refresh()
        case .failure(let error):
            stopLoader()
            showError(error)
        }
    }
    func archive() async {
        let task = Task { try await viewModel.archiveSubaccount() }
        switch await task.result {
        case .success:
            viewModel.refresh()
            presentArchivedSuccess()
        case .failure(let error):
            stopLoader()
            showError(error)
        }
    }
    func lightningTransfer() {
        let viewModel = LTRecoverFundsViewModel(
            wallet: viewModel.selectedSubaccount,
            amount: viewModel.selectedSubaccount?.lightningSession?.nodeState?.onchainBalanceSatoshi ?? 0,
            type: .sweep)
        pushLTRecoverFundsViewController(viewModel)
    }
    func pushLTRecoverFundsViewController(_ model: LTRecoverFundsViewModel) {
        let ltFlow = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = ltFlow.instantiateViewController(withIdentifier: "LTRecoverFundsViewController") as? LTRecoverFundsViewController {
            vc.viewModel = model
            vc.modalPresentationStyle = .overFullScreen
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    @MainActor
    func presentArchivedSuccess() {
        let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountArchivedViewController") as? AccountArchivedViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    func openLTSettingsViewController() {
        guard let lightningSession = viewModel.selectedSubaccount?.lightningSession else {
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
        case .cta:
            return viewModel.actions.count
        case .accounts:
            return viewModel.subaccounts.count
        case .transactions:
            return viewModel.txs?.count ?? 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .assetBalance:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AssetBalanceCell.identifier, for: indexPath) as? AssetBalanceCell {
                var satoshi: Int64?
                if let subaccount = viewModel.selectedSubaccount {
                    satoshi = subaccount.satoshi?[viewModel.assetId]
                } else {
                    satoshi = viewModel.balances?[viewModel.assetId]
                }
                cell.configure(
                    assetId: viewModel.assetId,
                    satoshi: satoshi ?? 0,
                    hideBalance: viewModel.hideBalance)
                cell.selectionStyle = .none
                return cell
            }
        case .actions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactActionsCell.identifier, for: indexPath) as? TransactActionsCell {
                cell.configure(onBuy: viewModel.isBTCAsset ? self.buy : nil, onSend: self.send, onReceive: self.receive)
                cell.selectionStyle = .none
                return cell
            }
        case .cta:
            if let cell = tableView.dequeueReusableCell(withIdentifier: ActionCell.identifier, for: indexPath) as? ActionCell {
                let action = viewModel.actions[indexPath.row]
                let model = ActionCellModel(action)
                cell.configure(
                    model: model,
                    onAction: {[weak self] in
                        switch model.type {
                        case .lightningTransfer:
                            self?.lightningTransfer()
                        }
                    })
                cell.selectionStyle = .none
                return cell
            }
        case .accounts:
            let subaccount = viewModel.subaccounts[safe: indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: DialogAccountCell.identifier, for: indexPath) as? DialogAccountCell
            if let cell, let subaccount {
                let model = AccountCellModel(
                    account: subaccount,
                    satoshi: subaccount.satoshi?[viewModel.assetId],
                    assetId: viewModel.assetId)
                cell.configure(
                    model: model,
                    isSelectable: true,
                    hideBalance: viewModel.hideBalance,
                    onTap: {[weak self] in
                        self?.onAccountTap(indexPath)
                    })
                cell.selectionStyle = .none
                return cell
            }
        case .transactions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.identifier, for: indexPath) as? TransactionCell, let tx = viewModel.txs?[indexPath.row] {
                let wm = WalletManager.current
                let blockHeight = tx.isLiquid ? wm?.liquidBlockHeight() : wm?.bitcoinBlockHeight()
                let model = TransactionCellModel(tx: tx, blockHeight: blockHeight ?? 0)
                cell.configure(model: model, hideBalance: viewModel.hideBalance, onTap: {[weak self] in
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
            return viewModel.subaccounts.count > 0 ? sectionHeaderH : 0.1
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch sections[section] {
        case .transactions:
            if viewModel.txs?.count == 0 {
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
            if viewModel.txs?.count == 0 {
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
                account: viewModel.selectedSubaccount,
                currency: viewModel.currency(),
                hideBalance: viewModel.hideBalance)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func sendScreen() {
        let sendAddressInputViewModel = SendAddressInputViewModel(
            input: nil,
            preferredAccount: viewModel.selectedSubaccount,
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
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController, let account = viewModel.selectedSubaccount {
            let waParam: (WalletItem, AnyOrAsset) = (account, .asset(viewModel.assetId))
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
        viewModel.refresh()
    }
}
extension ManageAssetViewController: AccountSettingsViewControllerDelegate {
    func didSelectAction(_ type: AccountSettingsType) {
        switch type {
        case .rename(let current):
            accountRename(current)
        case .watchonly:
            if viewModel.selectedSubaccount?.isSinglesig == true {
                showDescriptor()
            } else if viewModel.selectedSubaccount?.isMultisig == true {
                if let session = viewModel.selectedSubaccount?.session {
                    openWatchOnly(session: session)
                }
            }
        case .archive:
            Task { [weak self] in await self?.archive() }
        }
    }
}
extension ManageAssetViewController: DialogRenameViewControllerDelegate {
    func didRename(name: String, index: String?) {
        Task { [weak self] in await self?.rename(name) }
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
