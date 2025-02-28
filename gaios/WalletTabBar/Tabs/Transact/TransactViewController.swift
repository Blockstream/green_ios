import UIKit
import gdk
enum TransactSection: Int, CaseIterable {
    case header
    case balance
    case actions
    case transactions
}

class TransactViewController: UIViewController {

    var walletViewModel: WalletViewModel!
    @IBOutlet weak var tableView: UITableView!

    private var sectionHeaderH: CGFloat = 54.0
    private var footerH: CGFloat = 54.0

    var hideBalance = false // to move in parent

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
    }

    func setContent() {
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    func register() {
        ["TabHeaderCell", "BalanceCell", "TransactActionsCell",
        "TransactionCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    @objc func pull(_ sender: UIRefreshControl? = nil) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {[weak self] in
            self?.tableView.refreshControl?.endRefreshing()
        }
    }
    func pushTransactionViewController(_ tx: Transaction) {

        let storyboard = UIStoryboard(name: "TxDetails", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TxDetailsViewController") as? TxDetailsViewController, let wallet = tx.subaccountItem {
            vc.vm = TxDetailsViewModel(wallet: wallet, transaction: tx)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func receiveScreen() {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController {
            guard let model = walletViewModel.accountCellModels[safe: 0] else { return }
            vc.viewModel = ReceiveViewModel(account: model.account,
                                            accounts: walletViewModel.subaccounts)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func buyScreen() {
        let storyboard = UIStoryboard(name: "BuyFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "BuyViewController") as? BuyViewController {
            guard let model = walletViewModel.accountCellModels[safe: 0] else { return }
            var account: WalletItem? = model.account
            if account?.networkType.liquid ?? false {
                account = walletViewModel.wm?.bitcoinSubaccounts.first
            }
            if let account {
                vc.viewModel = BuyViewModel(account: account, side: .buy)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func sendScreen() {
        
        guard let model = walletViewModel.accountCellModels[safe: 0] else { return }
        let sendAddressInputViewModel = SendAddressInputViewModel(
            input: nil,
            preferredAccount: model.account,
            txType: walletViewModel.isSweepEnabled() ? .sweep : .transaction)
        
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAddressInputViewController") as? SendAddressInputViewController {
            vc.viewModel = sendAddressInputViewModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
extension TransactViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return TransactSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch TransactSection(rawValue: section) {
        case .header:
            return 1
        case .balance:
            return 1
        case .actions:
            return 1
        case .transactions:
            return walletViewModel.txCellModels.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch TransactSection(rawValue: indexPath.section) {
        case .actions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactActionsCell.identifier, for: indexPath) as? TransactActionsCell {
                cell.configure(onBuy: { [weak self] in
                    self?.buyScreen()
                }, onSend: {[weak self] in
                    self?.sendScreen()
                }, onReceive: {[weak self] in
                    self?.receiveScreen()
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
                cell.configure(model: walletViewModel.balanceCellModel,
                               hideBalance: hideBalance,
                               hideBtnExchange: true,
                               onHide: {[weak self] value in
//                    self?.hideBalance = value
//
//                    self?.reloadSections([TransactSection.account, TransactSection.transaction], animated: false)
                },
                               onAssets: {[weak self] in
//                    self?.assetsScreen()
                }, onConvert: { [weak self] in
//                    Task {
//                        try? await self?.viewModel.rotateBalanceDisplayMode()
//                        await MainActor.run { self?.reloadSections([.balance, .account, .transaction], animated: false) }
//                    }
                }, onExchange: { [weak self] in
//                    self?.showDenominationExchange()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .transactions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.identifier, for: indexPath) as? TransactionCell {
                cell.configure(model: walletViewModel.txCellModels[indexPath.row], hideBalance: hideBalance)
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch TransactSection(rawValue: section) {
        case .transactions:
            return sectionHeaderH
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch TransactSection(rawValue: section) {
        case .header:
            return 0.1
            // return headerH
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch TransactSection(rawValue: indexPath.section) {
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch TransactSection(rawValue: section) {
        case .transactions:
            return sectionHeader("Transactions".localized)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch TransactSection(rawValue: section) {
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch TransactSection(rawValue: indexPath.section) {
        case .transactions:
            return indexPath
        default:
            return nil // indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch TransactSection(rawValue: indexPath.section) {

            // TODO: animation
        case .transactions:
            let tx = walletViewModel.txCellModels[indexPath.row].tx
            if tx.isLightningSwap ?? false {
                if tx.isInProgressSwap ?? false {
                    DropAlert().warning(message: "id_swap_is_in_progress".localized)
                } else {
                    pushTransactionViewController(tx)
                }
            } else {
                pushTransactionViewController(tx)
            }
            tableView.deselectRow(at: indexPath, animated: false)
        default:
            break
        }
    }
}
extension TransactViewController {
    func sectionHeader(_ txt: String) -> UIView {

        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: sectionHeaderH))
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
}
