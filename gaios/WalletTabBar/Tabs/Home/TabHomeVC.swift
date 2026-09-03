import UIKit
import core
import greenaddress

class TabHomeVC: TabViewController {

    private let viewModel: TabHomeVM
    private lazy var transactActionsCoordinator = TransactActionsCoordinator(viewController: self, dataSource: viewModel)
    private var settingsCoordinator: SettingsCoordinator? { walletTab.settingsCoordinator }
    @IBOutlet weak var tableView: UITableView?

    init?(coder: NSCoder, viewModel: TabHomeVM) {
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(promosDidLoad),
            name: PromoManager.promosDidLoad,
            object: nil
        )
        attachSettingsCoordinator()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attachSettingsCoordinator()
    }

    private func attachSettingsCoordinator() {
        walletTab.attachSettingsCoordinator()
    }

    deinit {
        NotificationCenter.default.removeObserver(self,name: PromoManager.promosDidLoad, object: nil)
    }

    func onUpdate(feature: RefreshFeature?) {
        switch feature {
        case .priceChart:
            if tableView?.refreshControl?.isRefreshing == true {
                tableView?.refreshControl?.endRefreshing()
            }
            tableView?.reloadData()
        case .alertCards, .promos, .balance, .subaccounts, .settings:
            if tableView?.refreshControl?.isRefreshing == true {
                tableView?.refreshControl?.endRefreshing()
            }
            if feature == .promos {
                let section = TabHomeSection.promo.rawValue
                let currentRowCount = tableView?.numberOfRows(inSection: section) ?? 0
                let updatedRowCount = min(viewModel.promos.count, 1)

                if currentRowCount != updatedRowCount {
                    tableView?.reloadSections(IndexSet(integer: section), with: .automatic)
                } else if let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: section)) as? PromoContainerCell {
                    let shouldUpdateHeight = cell.isPaginationVisible != (viewModel.promos.count > 1)
                    cell.update(with: viewModel.promos)
                    if shouldUpdateHeight {
                        tableView?.beginUpdates()
                        tableView?.endUpdates()
                    }
                }
                return
            }
            tableView?.reloadData()
        default:
            break
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPriceChart()
        if let url = URLSchemeManager.shared.url {
            URLSchemeManager.shared.url = nil
            transactActionsCoordinator.send(input: url.absoluteString)
        }
    }

    func setContent() {
        tableView?.refreshControl = UIRefreshControl()
        tableView?.refreshControl!.tintColor = UIColor.white
        tableView?.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    func register() {
        ["TabHeaderCell", "BalanceCell", "AlertCardCell", "WalletAssetCell", "PriceChartCell", "TransactActionsCell", PromoContainerCell.identifier].forEach {
            tableView?.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    @objc func pull(_ sender: UIRefreshControl? = nil) {
        viewModel.refresh(features: [.discover])
    }

    @objc nonisolated private func promosDidLoad() {
        Task { @MainActor [weak self] in
            self?.viewModel.refresh(features: [.promos])
        }
    }
    private func refreshPriceChart() {
        viewModel.refresh(features: [.priceChart])
    }
}

extension TabHomeVC { // navigation
    func onPromo(promo: Promo) {
        PromoManager.shared.trackPromoAction(promo: promo)
        if let url = URL(string: promo.cta.url), url.scheme?.lowercased() == "https" {
            SafeNavigationManager.shared.navigate(url, exitApp: true)
        }
    }
    func promoDismiss() {
        viewModel.refresh(features: [.promos])
    }
    func backupAlertDismiss() {
        BackupHelper.shared.addToDismissed(walletId: viewModel.mainWallet.id, position: .homeTab)
        viewModel.refresh(features: [.alertCards])
    }
    func presentReEnable2fa() async {
        let storyboard = UIStoryboard(name: "ReEnable2fa", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReEnable2faViewController") as? ReEnable2faViewController {
            vc.vm = ReEnable2faViewModel(expiredSubaccounts: await viewModel.getExpiredSubaccounts() ?? [])
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func remoteAlertDismiss() {
        viewModel.dismissRemoteAlert()
    }
    func systemMessageScreen(msg: SystemMessage) {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SystemMessageViewController") as? SystemMessageViewController {
            vc.msg = msg
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func twoFactorResetMessageScreen(msg: TwoFactorResetMessage) {
        attachSettingsCoordinator()
        guard let coordinator = settingsCoordinator else { return }
        let networkId = NetworkId(network: msg.network) ?? coordinator.defaultMultisigNetworkId
        coordinator.navigate(to: .learn2fa(coordinator.learn2faViewModel(networkId: networkId, message: msg)))
    }
    func receive() {
        transactActionsCoordinator.receive()
    }
    func buy() {
        transactActionsCoordinator.buy()
    }

    func swapScreen() {
        transactActionsCoordinator.swap()
    }
    func send() {
        transactActionsCoordinator.send()
    }
}
extension TabHomeVC: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return TabHomeSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch TabHomeSection(rawValue: section) {
        case .header:
            return 1
        case .balance:
            return 1
        case .backup:
            return viewModel.backupCards.count
        case .card:
            return viewModel.alertCards.count
        case .actions:
            return 1
        case .promo:
            return min(viewModel.promos.count, 1)
        case .assets:
            return viewModel.balances?.count ?? 0
        case .chart:
            return 1
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch TabHomeSection(rawValue: indexPath.section) {
        case .header:
            let headerIcon = UIImage(named: viewModel.mainWallet.gdkNetwork.mainnet ? "ic_wallet" : "ic_wallet_testnet")?.maskWithColor(color: .white)
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell, let headerIcon {
                cell.configure(title: "id_home".localized, icon: headerIcon, tab: .home, onTap: {[weak self] in
                    self?.walletTab.switchNetwork()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .actions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactActionsCell.identifier, for: indexPath) as? TransactActionsCell {
                cell.configure(
                    onBuy: { [weak self] in self?.buy() },
                    onSend: { [weak self] in self?.send() },
                    onReceive: { [weak self] in self?.receive() },
                    onSwap: viewModel.canSwap() ? { [weak self] in self?.swapScreen() } : nil)
                cell.selectionStyle = .none
                return cell
            }
        case .balance:
            if let cell = tableView.dequeueReusableCell(withIdentifier: BalanceCell.identifier, for: indexPath) as? BalanceCell {
                let balanceItem = BalanceItem(satoshi: viewModel.totals?.1, assetId: viewModel.totals?.0)
                cell.configure(
                    balances: viewModel.balances,
                    currency: viewModel.defaultCurrency,
                    item: balanceItem,
                    denomBalance: viewModel.state.balanceDisplayMode,
                    hideBalance: viewModel.hideBalance,
                    hideBtnExchange: true,
                    onHide: {[weak self] value in
                        Task {
                            await self?.viewModel.hideBalance(value)
                            await MainActor.run {
                                self?.tableView?.reloadData()
                            }
                        }
                    },
                    onAssets: {}, onConvert: {
                        Task { [weak self] in
                            await self?.viewModel.rotateBalanceDisplayMode()
                            await MainActor.run {
                                self?.tableView?.reloadData()
                            }
                        }
                    },
                    onExchange: {
                    })
                cell.selectionStyle = .none
                return cell
            }
        case .backup:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                let alertCard = AlertCardCellModel(type: viewModel.backupCards[indexPath.row])
                switch alertCard.type {
                case .backup:
                    cell.configure(alertCard,
                                   onLeft: {[weak self] in
                        if let vc = WalletNavigator.backupIntro(.quiz) {
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
        case .card:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                let alertCard = AlertCardCellModel(type: viewModel.alertCards[indexPath.row])
                switch alertCard.type {
                case .reset(let msg), .dispute(let msg):
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: {[weak self] in
                        self?.twoFactorResetMessageScreen(msg: msg)
                    }, onDismiss: nil)
                case .reactivate:
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .systemMessage(let msg):
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: {[weak self] in
                        self?.systemMessageScreen(msg: msg)
                    },
                                   onDismiss: nil)
                case .fiatMissing:
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .testnetNoValue:
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .ephemeralWallet:
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .remoteAlert(let remoteAlert):
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: {
                                        if let link = remoteAlert.link, let url = URL(string: link) {
                                            SafeNavigationManager.shared.navigate(url)
                                        }
                                    },
                                   onDismiss: {[weak self] in
                        self?.remoteAlertDismiss()
                    })
                case .login:
                    let handleAlertGesture: (() -> Void)? = { [weak self] in
                        Task { [weak self] in
                            self?.startLoader(message: "id_connecting".localized)
                            let task = Task.detached { [weak self] in
                                try await self?.viewModel.relogin()
                            }
                            switch await task.result {
                            case .success:
                                self?.viewModel.refresh(features: [.subaccounts])
                                self?.viewModel.refresh(features: [.alertCards, .balance, .txs(reset: true)])
                                self?.stopLoader()
                            case .failure(let error):
                                self?.stopLoader()
                                DropAlert().error(message: error.description().localized)
                            }
                        }
                    }
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: handleAlertGesture,
                                   onDismiss: nil)
                case .lightningMaintenance:
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .lightningServiceDisruption:
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .reEnable2fa:
                    cell.configure(alertCard,
                                   onLeft: nil,
                                   onRight: {[weak self] in
                        Task { await self?.presentReEnable2fa() }
                    },
                                   onDismiss: nil)
                case .backup:
                    break
                case .descriptorInfo, .TFAWarnMulti, .TFAInfoExpire, .lightningBeta, .lightningOnJade:
                    break
                }
                cell.selectionStyle = .none
                return cell
            }
        case .promo:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PromoContainerCell.identifier, for: indexPath) as? PromoContainerCell {
                cell.configure(
                    with: viewModel.promos,
                    onAction: { [weak self] promo in
                        self?.onPromo(promo: promo)
                    },
                    onDismiss: { [weak self] promo in
                        PromoManager.shared.trackPromoDismiss(promo: promo)
                        self?.promoDismiss()
                    },
                    onImpression: { promo in
                        PromoManager.shared.trackPromoImpression(promo: promo)
                    }
                )
                cell.selectionStyle = .none
                return cell
            }
            return UITableViewCell()
        case .assets:
            if let cell = tableView.dequeueReusableCell(withIdentifier: WalletAssetCell.identifier, for: indexPath) as? WalletAssetCell {
                let item = viewModel.assetAmountList?.amounts[indexPath.row] as? (String, Int64)
                let walletAssetCellModel = WalletAssetCellModel(assetId: item?.0 ?? "btc", satoshi: item?.1 ?? 0, masked: viewModel.hideBalance, hidden: false)
                cell.configure(model: walletAssetCellModel, onTap: { self.didSelectAssetRowAt(indexPath: indexPath)})
                cell.selectionStyle = .none
                return cell
            }
        case .chart:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PriceChartCell.identifier, for: indexPath) as? PriceChartCell {
                cell.configure(
                    viewModel.priceChartCellModel,
                    timeFrame: viewModel.priceChartTimeFrame,
                    onBuy: {[weak self] in
                        self?.buy()
                    }, onNewFrame: {[weak self] timeFrame in
                        Task { await self?.viewModel.updatePriceChartTimeFrame(timeFrame) }
                    })
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch TabHomeSection(rawValue: section) {
        case .assets, .chart:
            return sectionHeaderH
        case .card:
            return viewModel.alertCards.count > 0 ? 10.0 : 0.1
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch TabHomeSection(rawValue: section) {
        case .assets:
            if viewModel.balances?.count == 0 {
                return footerH
            }
            return 0.1
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch TabHomeSection(rawValue: indexPath.section) {
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch TabHomeSection(rawValue: section) {
        case .assets:
            return sectionHeader("id_assets".localized)
        case .chart:
            return sectionHeader("id_bitcoin_price".localized)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch TabHomeSection(rawValue: section) {
        case .assets:
            if viewModel.balances?.count == 0 {
                return sectionFooter("id_you_dont_have_any_assets_yet".localized)
            }
            return nil
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch TabHomeSection(rawValue: indexPath.section) {
        case .assets:
            return indexPath
        default:
            return nil
        }
    }

    func didSelectAssetRowAt(indexPath: IndexPath) {
        let assetAmount = viewModel.assetAmountList?.amounts[indexPath.row]
        let assetId = assetAmount?.0 ?? AssetInfo.btcId
        let subaccounts = viewModel.wm.subaccountsFor(assetId: assetId)
        let vc = manageAssetViewController(assetId: assetId, subaccounts: subaccounts)
        navigationController?.pushViewController(vc, animated: true)
    }

    @MainActor func manageAssetViewController(assetId: String, subaccounts: [Account]) -> ManageAssetViewController {
        let storyboard = UIStoryboard(name: "ManageAsset", bundle: nil)
        let viewModel = ManageAssetViewModel(
            walletDataModel: viewModel.walletDataModel,
            wm: viewModel.wm,
            mainWallet: viewModel.mainWallet,
            assetId: assetId,
            selectedSubaccount: subaccounts.count == 1 ? subaccounts.first : nil)
        return storyboard.instantiateViewController(identifier: "ManageAssetViewController") { coder in
            ManageAssetViewController(coder: coder, viewModel: viewModel)
        }
    }
}
extension TabHomeVC {
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
extension TabHomeVC: SystemMessageDelegate {
    func didAcceptSystemMessage(_ message: SystemMessage) {
        viewModel.refresh(features: [.alertCards])
    }
}
