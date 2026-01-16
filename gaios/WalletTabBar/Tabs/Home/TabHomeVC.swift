import UIKit
import core
import gdk
import greenaddress

class TabHomeVC: TabViewController {

    private let viewModel: TabHomeVM
    @IBOutlet weak var tableView: UITableView?
    var timeFrame: ChartTimeFrame = .day

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
        viewModel.refresh(features: [.alertCards, .promos, .balance, .subaccounts, .priceChart])
    }

    func onUpdate(feature: RefreshFeature?) {
        switch feature {
        case .alertCards, .promos, .balance, .subaccounts, .priceChart, .settings:
            if tableView?.refreshControl?.isRefreshing == true {
                tableView?.refreshControl?.endRefreshing()
            }
            tableView?.reloadData()
        default:
            break
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let url = URLSchemeManager.shared.url {
            URLSchemeManager.shared.url = nil
            sendScreen(input: url.absoluteString)
        }
    }

    func setContent() {
        tableView?.refreshControl = UIRefreshControl()
        tableView?.refreshControl!.tintColor = UIColor.white
        tableView?.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    func register() {
        ["TabHeaderCell", "BalanceCell", "AlertCardCell", "WalletAssetCell", "PromoLayout0Cell", "PromoLayout1Cell", "PromoLayout2Cell", "PriceChartCell"].forEach {
            tableView?.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    @objc func pull(_ sender: UIRefreshControl? = nil) {
        viewModel.refresh(features: [.discover])
    }

    func buy() {
        Task {
            await buyScreen(currency: viewModel.defaultCurrency ?? "USD", hideBalance: viewModel.hideBalance)
        }
    }
}

extension TabHomeVC { // navigation
    func onPromo(promo: Promo, source: PromoScreen) {
        if promo.is_small == true {
            PromoManager.shared.promoAction(promo: promo, source: source)
            if let url = URL(string: promo.link ?? "") {
                SafeNavigationManager.shared.navigate(url, exitApp: true)
            }
        } else {
            PromoManager.shared.promoOpen(promo: promo, source: source)
            let storyboard = UIStoryboard(name: "PromoFlow", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "PromoViewController") as? PromoViewController {
                vc.promo = promo
                vc.source = source
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: false, completion: nil)
            }
        }
    }
    func promoDismiss() {
        viewModel.refresh(features: [.promos])
    }
    func backupAlertDismiss() {
        BackupHelper.shared.addToDismissed(walletId: viewModel.mainAccount.id, position: .homeTab)
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
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "Learn2faViewController") as? Learn2faViewController {
            vc.message = msg
            navigationController?.pushViewController(vc, animated: true)
        }
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
        case .assets:
            return viewModel.balances?.count ?? 0
        case .chart:
            return 1
        case .promo:
            return viewModel.promos.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch TabHomeSection(rawValue: indexPath.section) {
        case .header:
            let headerIcon = UIImage(named: viewModel.mainAccount.gdkNetwork.mainnet ? "ic_wallet" : "ic_wallet_testnet")?.maskWithColor(color: .white)
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell, let headerIcon {
                cell.configure(title: "id_home".localized, icon: headerIcon, tab: .home, onTap: {[weak self] in
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
                        if let vc = AccountNavigator.backupIntro(.quiz) {
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
                                self?.viewModel.refresh(features: [.alertCards, .subaccounts, .balance, .txs(reset: true)])
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
                case .descriptorInfo, .TFAWarnMulti, .TFAInfoExpire:
                    break
                }
                cell.selectionStyle = .none
                return cell
            }
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
                    PriceChartCellModel(
                        priceChartModel: viewModel.priceCache,
                        currency: Api.shared.currency,
                        isReloading: viewModel.priceCache == nil),
                    timeFrame: timeFrame,
                    onBuy: {[weak self] in
                        self?.buy()
                    }, onNewFrame: {[weak self] timeFrame in
                        self?.timeFrame = timeFrame
                    })
                cell.selectionStyle = .none
                return cell
            }
        case .promo:
            let cellModel = viewModel.promos[indexPath.row]
            if cellModel.promo.layout_small == 2 {
                if let cell = tableView.dequeueReusableCell(withIdentifier: "PromoLayout2Cell", for: indexPath) as? PromoLayout2Cell {
                    cell.configure(cellModel, onAction: { [weak self] in
                        self?.onPromo(promo: cellModel.promo, source: cellModel.source)
                    }, onDismiss: { [weak self] in
                        self?.promoDismiss()
                    })
                    cell.selectionStyle = .none
                    return cell
                }
            } else if cellModel.promo.layout_small == 1 {
                if let cell = tableView.dequeueReusableCell(withIdentifier: "PromoLayout1Cell", for: indexPath) as? PromoLayout1Cell {
                    cell.configure(cellModel, onAction: { [weak self] in
                        self?.onPromo(promo: cellModel.promo, source: cellModel.source)
                    }, onDismiss: { [weak self] in
                        self?.promoDismiss()
                    })
                    cell.selectionStyle = .none
                    return cell
                }
            } else {
                if let cell = tableView.dequeueReusableCell(withIdentifier: "PromoLayout0Cell", for: indexPath) as? PromoLayout0Cell {
                    cell.configure(cellModel, onAction: { [weak self] in
                        self?.onPromo(promo: cellModel.promo, source: cellModel.source)
                    }, onDismiss: { [weak self] in
                        self?.promoDismiss()
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
        let amounts = viewModel.assetAmountList?.amounts[indexPath.row]
        let assetId = amounts?.0 ?? "btc"
        let subaccounts = viewModel.subaccounts?.filter({$0.satoshi?.keys.contains(assetId) ?? false })
        let vc = manageAssetViewController(assetId: assetId, subaccounts: subaccounts ?? [])
        navigationController?.pushViewController(vc, animated: true)
    }

    @MainActor func manageAssetViewController(assetId: String, subaccounts: [WalletItem]) -> ManageAssetViewController {
        let storyboard = UIStoryboard(name: "ManageAsset", bundle: nil)
        let viewModel = ManageAssetViewModel(
            walletDataModel: viewModel.walletDataModel,
            wallet: viewModel.wallet,
            mainAccount: viewModel.mainAccount,
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
    func didAcceptSystemMessage(_ message: gdk.SystemMessage) {
        viewModel.refresh(features: [.alertCards])
    }
}
