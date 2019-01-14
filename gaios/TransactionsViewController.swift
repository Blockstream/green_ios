import Foundation
import UIKit
import PromiseKit


class TransactionsController: UITableViewController {

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
        tableView.separatorColor = UIColor.customTitaniumLight()
        tableView.tableHeaderView = getWalletCardView()
        tableView.refreshControl = UIRefreshControl()
        tableView.bounces = true
        tableView.alwaysBounceVertical = true
        tableView.refreshControl!.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshTransactions(_:)), name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshTransactions(_:)), name: NSNotification.Name(rawValue: EventType.Block.rawValue), object: nil)
        reloadWalletCardView(tableView.tableHeaderView as! WalletFullCardView)
        loadTransactions()
        updateBalance()
    }

    func updateBalance() {
        guard let wallet = presentingWallet else { return }
        wallet.getBalance().get { balance in
            let view = self.tableView.tableHeaderView as! WalletFullCardView
            view.balance.text = String.formatBtc(satoshi: wallet.satoshi)
            let res = try getSession().convertAmount(input: ["satoshi": wallet.satoshi])
            view.balanceFiat.text = String(format: "≈ %@ %@", (res!["fiat"] as? String)!, getGAService().getSettings()!.getCurrency())
        }.done { _ in }.catch { _ in }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Block.rawValue), object: nil)
    }

    @objc func refreshTransactions(_ notification: NSNotification) {
        guard let dict = notification.userInfo as NSDictionary? else { return }
        var subaccounts = [UInt32]()
        if notification.name.rawValue == EventType.Block.rawValue {
            let saccounts = AccountStore.shared.wallets.map { return $0.pointer }
            subaccounts.append(contentsOf: saccounts)
        } else {
            if let saccounts =  dict["subaccounts"] as! [UInt32]? {
                subaccounts.append(contentsOf: saccounts)
            }
        }
        if subaccounts.filter({ UInt32($0) == presentingWallet?.pointer }).count > 0 {
            Guarantee().done {
                self.reloadWalletCardView(self.tableView.tableHeaderView as! WalletFullCardView)
                self.loadTransactions()
                self.updateBalance()
            }
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
        } else if (AccountStore.shared.getBlockheight() - item.blockHeight < 6) {
            let confirmCount = AccountStore.shared.getBlockheight() - item.blockHeight + 1
            cell.status.text = String(format: "(%d/6)", confirmCount)
            cell.status.textColor = UIColor.red
        } else {
            cell.status.text = NSLocalizedString("id_completed", comment: "")
            cell.status.textColor = UIColor.customTitaniumLight()
        }
        cell.selectionStyle = .none
        cell.date.text = item.date()
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
        Guarantee().compactMap(on: bgq) {
            try getSession().getTransactions(subaccount: (self.presentingWallet?.pointer)!, page: 0)
        }.compactMap(on: bgq) { data -> Transactions in
            let txList = (data["list"] as! [[String: Any]]).map { tx -> Transaction in
                return Transaction(tx)
            }
            let txs = Transactions(list: txList, nextPageId: data["next_page_id"] as! UInt32, pageId: data["page_id"] as! UInt32)
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
        view.stackButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action:  #selector(self.back)))
        return view
    }

    func reloadWalletCardView(_ view: WalletFullCardView){
        guard let wallet = presentingWallet else { return }
        guard let settings = getGAService().getTwoFactorReset() else { return }
        let bgq = DispatchQueue.global(qos: .background)
        Guarantee().compactMap(on: bgq) {
            return try getSession().getBalance(subaccount: wallet.pointer, numConfs: 0)
        }.compactMap { balance in
            let satoshi = balance["satoshi"] as! UInt64
            wallet.satoshi = satoshi
        }.done {_ in
            view.balance.text = String.formatBtc(satoshi: wallet.satoshi)
            view.walletName.text = wallet.localizedName()
            view.networkImage.image = UIImage.init(named: getNetwork() == "Mainnet".lowercased() ? "btc" : "btc_testnet")
            if settings.isResetActive {
                view.actionsView.isHidden = true
            }
        }.catch{ _ in }
    }

    @objc func back(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
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
        self.navigationController?.isNavigationBarHidden = false
        if let nextController = segue.destination as? SendBtcViewController {
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? ReceiveBtcViewController {
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? TransactionDetailViewController {
            nextController.transaction = sender as? Transaction
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? TransactionsController {
            nextController.presentingWallet = presentingWallet
        }
    }
}
