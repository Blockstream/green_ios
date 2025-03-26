import UIKit
import core
class TabHomeVC: TabViewController {

    @IBOutlet weak var tableView: UITableView?

    var timeFrame: ChartTimeFrame = .week

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSections([.balance, .assets], animated: false)

    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    func setContent() {
        tableView?.refreshControl = UIRefreshControl()
        tableView?.refreshControl!.tintColor = UIColor.white
        tableView?.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    func register() {
        ["TabHeaderCell", "BalanceCell", "WalletAssetCell", "PromoLayout0Cell", "PromoLayout1Cell", "PromoLayout2Cell", "PriceChartCell"].forEach {
            tableView?.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    @objc func pull(_ sender: UIRefreshControl? = nil) {
        Task.detached { [weak self] in
            await self?.walletTab.reload()
            await MainActor.run { [weak self] in
                self?.tableView?.refreshControl?.endRefreshing()
            }
        }
    }

    @MainActor
    func reloadSections(_ sections: [TabHomeSection], animated: Bool) {
        if animated {
            tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
//        if sections.contains(TabHomeVC.account) {
//            tableView.selectRow(at: IndexPath(row: sIdx, section: WalletSection.account.rawValue), animated: false, scrollPosition: .none)
//        }
//        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
//            self.tableView.refreshControl?.endRefreshing()
//        }
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
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: false, completion: nil)
            }
        }
    }
    func promoDismiss() {
        Task {
            await walletModel.reloadPromoCards()
            reloadSections([.promo], animated: true)
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
                cell.configure(title: "Home".localized, onTap: {[weak self] in
                    self?.walletTab.walletsMenu()
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
        case .assets:
            if let cell = tableView.dequeueReusableCell(withIdentifier: WalletAssetCell.identifier, for: indexPath) as? WalletAssetCell {
                cell.configure(model: walletModel.walletAssetCellModels[indexPath.row], hideBalance: walletModel.hideBalance)
                cell.selectionStyle = .none
                return cell
            }
        case .chart:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PriceChartCell.identifier, for: indexPath) as? PriceChartCell {

                cell.configure(PriceChartCellModel(priceChartModel: Api.shared.priceCache,
                                                   currency: Api.shared.currency,
                                                   isReloading: walletTab.isReloading), timeFrame: timeFrame, onBuy: {[weak self] in
                    self?.buy()
                }, onNewFrame: {[weak self] timeFrame in
                    self?.timeFrame = timeFrame
                    self?.reloadSections([.chart], animated: false)
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
                return sectionFooter("You don’t have any transactions yet.".localized)
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch TabHomeSection(rawValue: indexPath.section) {
        case .assets:
            let model = walletModel.walletAssetCellModels[indexPath.row]
            let dialogModel = DialogAccountsViewModel(
                assetInfo: WalletManager.current?.info(for: model.assetId),
                accountCellModels: walletModel.accountCellModelsBy(model.assetId),
                hideBalance: walletModel.hideBalance)
            accountsScreen(model: dialogModel)
        default:
            break
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
