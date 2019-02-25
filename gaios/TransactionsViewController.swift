import Foundation
import UIKit
import PromiseKit

protocol SubaccountDelegate
{
    func onChange(_ pointer: UInt32)
}

class TransactionsController: UITableViewController, SubaccountDelegate {

    var pointerWallet : UInt32 = 0
    var presentingWallet: WalletItem? = nil
    var items: Transactions? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = UINib(nibName: "TransactionTableCell", bundle: nil)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(nib, forCellReuseIdentifier: "TransactionTableCell")
        tableView.allowsSelection = true
        tableView.isUserInteractionEnabled = true
        tableView.tableHeaderView = getWalletCardView()!
        tableView.bounces = true
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshTransactions(_:)), name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshTransactions(_:)), name: NSNotification.Name(rawValue: EventType.Block.rawValue), object: nil)

        if presentingWallet?.pointer != pointerWallet {
            // clear tx list only after a subaccount change in order to provide cache in offline mode
            items = Transactions(list: [])
            tableView.reloadData()
        }
        loadWallet()
        loadTransactions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let controller = self.tabBarController as? TabViewController else { return }
        controller.snackbar.isHidden = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Block.rawValue), object: nil)
        guard let controller = self.tabBarController as? TabViewController else { return }
        controller.snackbar.isHidden = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let headerView = tableView.tableHeaderView else { return }
        let height = headerView.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
        if height != headerView.frame.size.height {
            headerView.frame.size.height = height
            tableView.tableHeaderView = headerView
        }
    }

    @objc func refreshTransactions(_ notification: NSNotification) {
        guard let dict = notification.userInfo as NSDictionary? else { return }
        var subaccounts = [UInt32]()
        if notification.name.rawValue == EventType.Block.rawValue {
            subaccounts.append(pointerWallet)
        } else {
            if let saccounts =  dict["subaccounts"] as! [UInt32]? {
                subaccounts.append(contentsOf: saccounts)
            }
        }
        if subaccounts.filter({ $0 == pointerWallet }).count > 0 {
           self.loadWallet()
           self.loadTransactions()
        }
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let items = self.items else {
            return 0
        }
        return items.list.count
    }

    public override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 65
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TransactionTableCell", for: indexPath) as! TransactionTableCell
        guard let items = self.items, indexPath.row < items.list.count else {
            return cell
        }

        let item = items.list[indexPath.row]
        cell.replaceable.isHidden = !item.canRBF
        cell.amount.text = item.amount()
        if item.type == "redeposit" {
            cell.address.text = NSLocalizedString("id_redeposited", comment: String())
            cell.amount.textColor = UIColor.white
        } else if item.type == "incoming" {
            cell.address.text = NSLocalizedString("id_received", comment: String())
            cell.amount.textColor = UIColor.customMatrixGreen()
        } else {
            cell.address.text = item.address() ?? String()
            cell.amount.textColor = UIColor.white
        }
        if item.blockHeight == 0 {
            cell.status.text = NSLocalizedString("id_unconfirmed", comment: "")
            cell.status.textColor = UIColor.red
        } else if (getGAService().getBlockheight() - item.blockHeight < 5) {
            let confirmCount = getGAService().getBlockheight() - item.blockHeight + 1
            cell.status.textColor = UIColor.customTitaniumLight()
            cell.status.text = String(format: NSLocalizedString("id_d6_confirmations", comment: ""), confirmCount)
        } else {
            cell.status.text = NSLocalizedString("id_completed", comment: "")
            cell.status.textColor = UIColor.customTitaniumLight()
        }
        cell.selectionStyle = .none
        cell.date.text = item.date()
        cell.date.textColor = UIColor.customTitaniumLight()
        cell.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0)
        return cell;
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let items = self.items, indexPath.row < items.list.count else {
            return
        }
        let item = items.list[indexPath.row]
        showTransaction(tx: item)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    @objc func handleRefresh(_ sender: UIRefreshControl) {
        self.loadTransactions()
    }

    func loadTransactions() {
        let bgq = DispatchQueue.global(qos: .background)
        Guarantee().compactMap(on: bgq) {_ in
            try getSession().getTransactions(details: ["subaccount": self.pointerWallet])
        }.compactMap(on: bgq) { data -> Transactions in
            let txList = (data["list"] as! [[String: Any]]).map { tx -> Transaction in
                return Transaction(tx)
            }
            let txs = Transactions(list: txList)
            return txs
        }.done { txs -> Void in
            self.items = txs
            self.tableView.reloadData()
        }.ensure {
            if self.tableView.refreshControl!.isRefreshing {
                self.tableView.refreshControl!.endRefreshing()
            }
        }.catch { _ in
        }
    }

    func getWalletCardView() -> WalletFullCardView? {
        let view: WalletFullCardView = ((Bundle.main.loadNibNamed("WalletFullCardView", owner: self, options: nil)![0] as? WalletFullCardView)!)
        view.receiveView.addGestureRecognizer(UITapGestureRecognizer(target: self, action:  #selector(self.receiveToWallet)))
        view.sendView.addGestureRecognizer(UITapGestureRecognizer(target: self, action:  #selector(self.sendfromWallet)))
        view.stackButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action:  #selector(self.wallets)))
        return view
    }

    func loadWallet(){
        guard let twoFactorReset = getGAService().getTwoFactorReset() else { return }
        guard let settings = getGAService().getSettings() else { return }
        getSubaccount(self.pointerWallet).done { wallet in
            self.presentingWallet = wallet
            let view = self.tableView.tableHeaderView as! WalletFullCardView

            let attributedBalanceString = NSMutableAttributedString(string: String.toBtc(satoshi: wallet.satoshi).split(separator: " ").map(String.init).first!)
            attributedBalanceString.setKerning(kerning: 1.6, stringValue: attributedBalanceString.string)
            view.balance.attributedText = attributedBalanceString

            let attributedUnitString = NSMutableAttributedString(string: settings.denomination.toString())
            attributedUnitString.setKerning(kerning: 1.6, stringValue: attributedUnitString.string)
            view.unit.attributedText =  attributedUnitString

            let attributedFiatString = NSMutableAttributedString(string: String.toFiat(satoshi: wallet.satoshi))
            attributedFiatString.setKerning(kerning: 0.9, stringValue: attributedFiatString.string)
            view.balanceFiat.attributedText = attributedFiatString

            let attributedWalletString = NSMutableAttributedString(string: wallet.localizedName())
            attributedWalletString.setFont(font: UIFont.systemFont(ofSize: 16, weight: .semibold), stringValue: attributedWalletString.string)
            attributedWalletString.setKerning(kerning: 0.16, stringValue: attributedWalletString.string)

            view.walletName.attributedText = attributedWalletString
            view.networkImage.image = UIImage.init(named: getNetwork() == "Mainnet".lowercased() ? "btc" : "btc_testnet")
            if twoFactorReset.isResetActive {
                view.actionsView.isHidden = true
            } else if getGAService().isWatchOnly {
                view.sendImage.image = UIImage(named: "qr_sweep")
                view.sendLabel.text = NSLocalizedString("id_sweep", comment: "").uppercased()
            }
        }.catch{ _ in }
    }

    @objc func wallets(_ sender: UIButton) {
        self.performSegue(withIdentifier: "wallets", sender: self)
    }

    @objc func sendfromWallet(_ sender: UIButton) {
        self.performSegue(withIdentifier: "send", sender: self)
    }

    @objc func receiveToWallet(_ sender: UIButton) {
        self.performSegue(withIdentifier: "receive", sender: self)
    }

    func showTransaction(tx: Transaction) {
        self.performSegue(withIdentifier: "detail", sender: tx)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcViewController {
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? ReceiveBtcViewController {
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? TransactionDetailViewController {
            nextController.transaction = sender as? Transaction
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? WalletsViewController {
            nextController.subaccountDelegate = self
        }
    }

    func onChange(_ pointer: UInt32) {
        self.pointerWallet = pointer
    }
}
