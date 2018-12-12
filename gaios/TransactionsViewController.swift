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

        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshTransactions(_:)), name: NSNotification.Name(rawValue: "incomingTX"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshTransactions(_:)), name: NSNotification.Name(rawValue: "outgoingTX"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.newAddress(_:)), name: NSNotification.Name(rawValue: "addressChanged"), object: nil)

        loadTransactions()
    }

    @objc func refreshTransactions(_ notification: NSNotification) {
        if let dict = notification.userInfo as NSDictionary? {
            if let accounts = dict["subaccounts"] as? NSArray {
                for acc in accounts {
                    if (acc as! UInt32) == presentingWallet?.pointer {
                        loadTransactions()
                    }
                }
            }
        }
    }

    @objc func newAddress(_ notification: NSNotification) {
        if let dict = notification.userInfo as NSDictionary? {
            let pointer = dict["pointer"] as! UInt32
            if presentingWallet?.pointer == pointer {
                guard let wallet = tableView.tableHeaderView as? WalletCardHeader else {
                    return
                }
                let address = presentingWallet?.getAddress()
                wallet.addressLabel.text = address
                let uri = bip21Helper.btcURIforAddress(address: address!)
                wallet.qrImageView.image = QRImageGenerator.imageForTextDark(text: uri, frame: wallet.qrImageView.frame)
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

    func getWalletCardView() -> WalletCardHeader? {
        guard let wallet = presentingWallet else { return nil }

        let view: WalletCardHeader = ((Bundle.main.loadNibNamed("WalletCardHeader", owner: self, options: nil)![0] as? WalletCardHeader)!)

        view.balanceLabel.text = String.formatBtc(satoshi: wallet.satoshi)
        view.addressLabel.text = wallet.getAddress()
        view.nameLabel.text = wallet.localizedName()
        view.nameLabel.textColor = UIColor.customMatrixGreen()
        view.index = Int(wallet.pointer)
        view.wallet = wallet
        view.balanceLabel.textColor = UIColor.white
        let uri = bip21Helper.btcURIforAddress(address: wallet.getAddress())
        view.qrImageView.image = QRImageGenerator.imageForTextDark(text: uri, frame: view.qrImageView.frame)

        let tap = UITapGestureRecognizer(target: self, action: #selector(zoomQR))
        view.qrImageView.isUserInteractionEnabled = true
        view.qrImageView.addGestureRecognizer(tap)
        view.sendView.isHidden = AccountStore.shared.isWatchOnly
        view.dividerView.isHidden = AccountStore.shared.isWatchOnly
        view.receiveView.addGestureRecognizer(UITapGestureRecognizer(target: self, action:  #selector(self.receiveToWallet)))
        view.sendView.addGestureRecognizer(UITapGestureRecognizer(target: self, action:  #selector(self.self.sendfromWallet)))
        return view
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

    @objc func zoomQR(recognizer: UITapGestureRecognizer) {
        self.performSegue(withIdentifier: "address", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcViewController {
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? ReceiveBtcViewController {
            nextController.receiveAddress = presentingWallet?.getAddress()
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? TransactionDetailViewController {
            nextController.transaction = sender as? Transaction
            nextController.wallet = presentingWallet
        } else if let addressDetail = segue.destination as? AddressDetailViewController {
            addressDetail.wallet = presentingWallet
            addressDetail.providesPresentationContextTransitionStyle = true
            addressDetail.definesPresentationContext = true
            addressDetail.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
            addressDetail.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        } else if let nextController = segue.destination as? TransactionsController {
            nextController.presentingWallet = presentingWallet
        }
    }
}
