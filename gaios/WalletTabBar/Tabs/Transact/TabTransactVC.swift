import UIKit
import gdk

class TabTransactVC: TabViewController {

    @IBOutlet weak var tableView: UITableView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSections([.balance], animated: false)
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
        Task.detached { [weak self] in
            await self?.walletTab.reload()
            await MainActor.run { [weak self] in
                self?.tableView?.refreshControl?.endRefreshing()
            }
        }
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

    func txDetail(_ tx: Transaction) {
        txScreen(tx)
    }
    func receive() {
        receiveScreen(walletModel)
    }
    func buy() {
        buyScreen(walletModel)
    }
    func send() {
        sendScreen(walletModel)
    }
    func onTxTap(_ indexPath: IndexPath) {
        let tx = walletModel.txCellModels[indexPath.row].tx
        if tx.isLightningSwap ?? false {
            if tx.isInProgressSwap ?? false {
                DropAlert().warning(message: "id_swap_is_in_progress".localized)
            } else {
                txScreen(tx)
            }
        } else {
            txScreen(tx)
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
            return walletModel.txCellModels.count
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
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell {
                cell.configure(title: "Transact".localized)
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
                }, onExchange: {})
                cell.selectionStyle = .none
                return cell
            }
        case .transactions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.identifier, for: indexPath) as? TransactionCell {
                cell.configure(model: walletModel.txCellModels[indexPath.row], hideBalance: walletModel.hideBalance, onTap: {[weak self] in
                    self?.onTxTap(indexPath)
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
            if walletModel.cachedTransactions.count == 0 {
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
            return sectionHeader("Transactions".localized)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch TabTransactSection(rawValue: section) {
        case .transactions:
            if walletModel.cachedTransactions.count == 0 {
                return sectionFooter("You don’t have any transactions yet.".localized)
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
        let filteredIndexPaths = indexPaths.filter { $0.section == TabTransactSection.transactions.rawValue }
        let row = filteredIndexPaths.last?.row ?? 0
        if row > (walletModel.txCellModels.count - 3) {
            getTransactions()
        }
    }

    func getTransactions() {
        walletModel.reloadTransactions()
        reloadSections([.transactions], animated: false)
    }
}
