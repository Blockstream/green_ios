import UIKit
import gdk
import core

class TabTransactVC: TabViewController {

    @IBOutlet weak var tableView: UITableView?
    var assetId: String?
    var anyAsset: AnyAssetType?
    let viewModel: TabTransactVM

    init?(coder: NSCoder, viewModel: TabTransactVM) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("You must create this view controller with a view model.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
        viewModel.onUpdate = { [weak self] feature in
            DispatchQueue.main.async {
                self?.onUpdate(feature: feature)
            }
        }
        viewModel.refresh(features: [.balance, .txs(reset: true)])
    }
    func onUpdate(feature: RefreshFeature?) {
        switch feature {
        case .balance, .txs, .alertCards, .settings, .subaccounts:
            if tableView?.refreshControl?.isRefreshing == true {
                tableView?.refreshControl?.endRefreshing()
            }
            tableView?.reloadData()
        default:
            break
        }
    }

    func setContent() {
        tableView?.prefetchDataSource = self
        tableView?.refreshControl = UIRefreshControl()
        tableView?.refreshControl!.tintColor = UIColor.white
        tableView?.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    func register() {
        ["TabHeaderCell", "BalanceCell", "TransactActionsCell",
        "TransactionCell"].forEach {
            tableView?.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    @objc func pull(_ sender: UIRefreshControl? = nil) {
        viewModel.currentPage = 0
        viewModel.refresh(features: [.balance, .txs(reset: true)])
    }

    @MainActor
    func reloadSections(_ sections: [TabTransactSection], animated: Bool) {
        if animated {
            tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }
    func pushAssetSelectViewController() {
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AssetSelectViewController") as? AssetSelectViewController {
            vc.viewModel = viewModel.assetSelectViewModel(subaccounts: viewModel.subaccounts ?? [])
            vc.dismissOnSelect = false
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func pushDialogAccountsViewController(assetId: String, subaccounts: [WalletItem]) {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAccountsViewController") as? DialogAccountsViewController {
            vc.viewModel = viewModel.dialogAccountsViewModel(assetId: assetId, subaccounts: subaccounts, hideBalance: viewModel.hideBalance)
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }

    func receive() {
        pushAssetSelectViewController()
    }
    func buy() {
        Task {
            await buyScreen(currency: viewModel.defaultCurrency ?? "USD", hideBalance: viewModel.hideBalance)
        }
    }
    func send() {
        sendScreen(input: nil)
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

    func txScreen(_ tx: Transaction) {
        let storyboard = UIStoryboard(name: "TxDetails", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TxDetailsViewController") as? TxDetailsViewController, let wallet = tx.subaccount {
            vc.vm = TxDetailsViewModel(wallet: wallet, transaction: tx)
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
extension TabTransactVC: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return TabTransactSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch TabTransactSection(rawValue: section) {
        case .header:
            return 1
        case .balance:
            return 1
        case .actions:
            return 1
        case .transactions:
            return viewModel.txs?.count ?? 0
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch TabTransactSection(rawValue: indexPath.section) {
        case .actions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactActionsCell.identifier, for: indexPath) as? TransactActionsCell {
                cell.configure(onBuy: { [weak self] in
                    self?.buy()
                }, onSend: {[weak self] in
                    self?.send()
                }, onReceive: {[weak self] in
                    self?.receive()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .header:
            let headerIcon = UIImage(named: viewModel.mainAccount.gdkNetwork.mainnet ? "ic_wallet" : "ic_wallet_testnet")?.maskWithColor(color: .white)
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell, let headerIcon {
                cell.configure(title: "id_transact".localized, icon: headerIcon, tab: .transact, onTap: {[weak self] in
                    self?.walletTab.switchNetwork()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .balance:
            if let cell = tableView.dequeueReusableCell(withIdentifier: BalanceCell.identifier, for: indexPath) as? BalanceCell {
                let balanceItem = BalanceItem(satoshi: viewModel.totals?.1, assetId: viewModel.totals?.0)
                cell.configure(
                    item: balanceItem,
                    denomBalance: viewModel.balanceDisplayMode,
                    hideBalance: viewModel.hideBalance,
                    hideBtnExchange: true,
                    onHide: {[weak self] value in
                        Task { [weak self] in
                            try? await self?.viewModel.hideBalance(value)
                            self?.reloadSections([.balance], animated: false)
                        }
                    },
                    onAssets: {},
                    onConvert: {
                        Task { [weak self] in
                            await self?.viewModel.rotateBalanceDisplayMode()
                            self?.reloadSections([.balance], animated: false)
                        }
                    }, onExchange: {
                    })
                cell.selectionStyle = .none
                return cell
            }
        case .transactions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.identifier, for: indexPath) as? TransactionCell {
                let wm = WalletManager.current
                if let tx = viewModel.txs?[indexPath.row] {
                    let blockHeight = tx.isLiquid ? wm?.liquidBlockHeight() : wm?.bitcoinBlockHeight()
                    cell.configure(
                        model: TransactionCellModel(tx: tx, blockHeight: blockHeight ?? 0),
                        hideBalance: viewModel.hideBalance,
                        onTap: {[weak self] in
                            self?.onTxTap(indexPath)
                        })
                    cell.selectionStyle = .none
                    return cell
                }
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch TabTransactSection(rawValue: section) {
        case .transactions:
            return sectionHeaderH
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch TabTransactSection(rawValue: section) {
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
        switch TabTransactSection(rawValue: indexPath.section) {
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch TabTransactSection(rawValue: section) {
        case .transactions:
            return sectionHeader("id_transactions".localized)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch TabTransactSection(rawValue: section) {
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
        switch TabTransactSection(rawValue: indexPath.section) {
        case .transactions:
            return indexPath
        default:
            return nil // indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch TabTransactSection(rawValue: indexPath.section) {
        default:
            break
        }
    }
}
extension TabTransactVC {
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
extension TabTransactVC: UITableViewDataSourcePrefetching {
   // incremental transactions fetching from gdk
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        guard viewModel.txsCanLoadMore ?? false == true else { return } // there's no more data
        let threshold = (viewModel.txs?.count ?? 0) - 10 // Trigger when within 5 rows of the end
        let filteredIndexPaths = indexPaths.filter { $0.section == TabTransactSection.transactions.rawValue }
        let row = filteredIndexPaths.last?.row ?? 0
        if row >= threshold {
            viewModel.refresh(features: [.txs(reset: false)])
        }
    }
    func getLiquidSubaccounts() -> [WalletItem] {
        WalletManager.current?.liquidSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    func getLiquidAmpSubaccounts() -> [WalletItem] {
        WalletManager.current?.liquidAmpSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    func getLightningSubaccounts() -> [WalletItem] {
        if let subaccount = WalletManager.current?.lightningSubaccount {
            return [subaccount]
        } else {
            return []
        }
    }
    func getAccounts() -> [WalletItem] {
        switch anyAsset {
        case .liquid:
            return getLiquidSubaccounts()
        case .amp:
            return getLiquidAmpSubaccounts()
        case nil:
            break
        }
        if let asset = WalletManager.current?.info(for: self.assetId ?? "") {
            if asset.isLightning {
                return getLightningSubaccounts()
            } else if asset.isBitcoin {
                return getBitcoinSubaccounts()
            } else if asset.amp ?? false {
                return getLiquidAmpSubaccounts()
            }
        }
        return getLiquidSubaccounts()
    }
}

extension TabTransactVC: AssetSelectViewControllerDelegate {

    func didSelectAnyAsset(_ type: AnyAssetType) {
        self.assetId = nil
        self.anyAsset = type
        let accounts = getAccounts()
        if accounts.count == 1 {
            didSelectAccount(accounts.first)
        } else {
            pushDialogAccountsViewController(assetId: AssetInfo.lbtcId, subaccounts: accounts)
        }
    }

    func didSelectAsset(_ assetId: String) {
        self.assetId = assetId
        self.anyAsset = nil
        let accounts = getAccounts()
        if accounts.count == 1 {
            didSelectAccount(accounts.first)
        } else {
            pushDialogAccountsViewController(assetId: assetId, subaccounts: accounts)
        }
    }
}
extension TabTransactVC: DialogAccountsViewControllerDelegate {
    func didSelectAccount(_ walletItem: gdk.WalletItem?) {

        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let walletItem, let assetId, let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController {
            let waParam: (WalletItem, String) = (walletItem, assetId)
            vc.viewModel = ReceiveViewModel(waParam)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension TabTransactVC: TxDetailsViewControllerDelegate {
    func onMemoEdit() {
        viewModel.refresh(features: [.txs(reset: true)])
    }
}
