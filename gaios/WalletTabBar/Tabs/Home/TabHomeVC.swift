import UIKit
import core
import gdk
class TabHomeVC: TabViewController {

    @IBOutlet weak var tableView: UITableView?

    var timeFrame: ChartTimeFrame = .day

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView?.reloadData()
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
        Task.detached { [weak self] in
            await self?.walletTab.reload(discovery: true)
            await self?.walletTab.reloadChart()
            await MainActor.run { [weak self] in
                self?.tableView?.refreshControl?.endRefreshing()
            }
        }
    }

    @MainActor
    func reloadSections(_ sections: [TabHomeSection], animated: Bool) {
        if animated {
            tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .fade)
        } else {
            UIView.performWithoutAnimation {
                tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }

    func buy() {
        buyScreen(walletModel)
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
        walletModel.reloadPromoCards()
        reloadSections([.promo], animated: true)
    }
    func backupAlertDismiss() {
        Task {
            BackupHelper.shared.addToDismissed(walletId: walletModel.wm?.account.id, position: .homeTab)
            walletModel.reloadBackupCards()
            reloadSections([.backup], animated: true)
        }
    }
    func presentReEnable2fa() {
        let storyboard = UIStoryboard(name: "ReEnable2fa", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReEnable2faViewController") as? ReEnable2faViewController {
            vc.vm = walletModel.reEnable2faViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func remoteAlertDismiss() {
        Task {
            walletModel.remoteAlert = nil
            await walletModel.reloadAlertCards()
            reloadSections([.card], animated: true)
        }
    }
    func systemMessageScreen(msg: SystemMessage) {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SystemMessageViewController") as? SystemMessageViewController {
            vc.msg = msg
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
            return walletModel.backupCardCellModel.count
        case .card:
            return walletModel.alertCardCellModel.count
        case .assets:
            return walletModel.walletAssetCellModels.count
        case .chart:
            return 1
        case .promo:
            return walletModel.promoCardCellModel.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch TabHomeSection(rawValue: indexPath.section) {

        case .header:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell {
                cell.configure(title: "Home".localized, icon: walletModel.headerIcon, tab: .home, onTap: {[weak self] in
                    self?.walletTab.switchNetwork()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .balance:
            if let cell = tableView.dequeueReusableCell(withIdentifier: BalanceCell.identifier, for: indexPath) as? BalanceCell {

                cell.configure(model: walletModel.balanceCellModel,
                               hideBalance: walletModel.hideBalance,
                               hideBtnExchange: true,
                               onHide: {[weak self] value in
                    self?.walletTab.onHide(value)
                },
                               onAssets: {}, onConvert: {
                    Task { [weak self] in
                        try? await self?.walletModel.rotateBalanceDisplayMode()
                        await MainActor.run { self?.reloadSections([.balance], animated: false) }
                    }
                }, onExchange: { })
                cell.selectionStyle = .none
                return cell
            }
        case .backup:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                let alertCard = walletModel.backupCardCellModel[indexPath.row]
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
        case .card:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                let alertCard = walletModel.alertCardCellModel[indexPath.row]
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
                case .login(let network, let error):
                    let handleAlertGesture: (() -> Void)? = { [weak self] in
                        switch error {
                        case LoginError.hostUnblindingDisabled(_):
                            Task {
//                                try? await self?.viewModel.reconnectHW(network)
//                                await MainActor.run { self?.reload() }
                            }
                        default:
                            break
                        }
                    }
                    cell.configure(walletModel.alertCardCellModel[indexPath.row],
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
                        self?.presentReEnable2fa()
                    },
                                   onDismiss: nil)
                case .backup:
                    break
                case .descriptorInfo:
                    break
                }
                cell.selectionStyle = .none
                return cell
            }
        case .assets:
            if let cell = tableView.dequeueReusableCell(withIdentifier: WalletAssetCell.identifier, for: indexPath) as? WalletAssetCell {
                cell.configure(model: walletModel.walletAssetCellModels[indexPath.row], onTap: { self.didSelectAssetRowAt(indexPath: indexPath)})
                cell.selectionStyle = .none
                return cell
            }
        case .chart:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PriceChartCell.identifier, for: indexPath) as? PriceChartCell {
                cell.configure(
                    PriceChartCellModel(
                        priceChartModel: Api.shared.priceCache,
                        currency: Api.shared.currency,
                        isReloading: Api.shared.priceCache == nil),
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
            let cellModel = walletModel.promoCardCellModel[indexPath.row]
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
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch TabHomeSection(rawValue: section) {
        case .assets:
            if walletModel.walletAssetCellModels.count == 0 {
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
            return sectionHeader("Assets".localized)
        case .chart:
            return sectionHeader("Bitcoin Price".localized)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch TabHomeSection(rawValue: section) {
        case .assets:
            if walletModel.walletAssetCellModels.count == 0 {
                return sectionFooter("You don’t have any assets yet.".localized)
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
        let model = walletModel.walletAssetCellModels[indexPath.row]
        let storyboard = UIStoryboard(name: "ManageAsset", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ManageAssetViewController") as? ManageAssetViewController {
            vc.viewModel = ManageAssetViewModel(assetId: model.assetId, walletModel: walletModel)
            navigationController?.pushViewController(vc, animated: true)
        }
        /* legacy action
        let model = walletModel.walletAssetCellModels[indexPath.row]
        let name = WalletManager.current?.info(for: model.assetId).name ?? ""
        let dialogModel = DialogAccountsViewModel(
            title: name,
            hint: "Your " + name + " total balance is the sum of the balances across these accounts.",
            isSelectable: false,
            assetId: model.assetId,
            accounts: walletModel.accountsBy(model.assetId),
            hideBalance: walletModel.hideBalance)
        accountsScreen(model: dialogModel)
         */
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
