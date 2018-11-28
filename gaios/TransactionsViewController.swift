import Foundation
import UIKit
import PromiseKit

struct TransactionItem : Codable {

    enum CodingKeys : String, CodingKey {
        case addressees
        case blockHeight = "block_height"
        case canRBF = "can_rbf"
        case createdAt = "created_at"
        case fee
        case feeRate = "fee_rate"
        case hash = "txhash"
        case memo
        case satoshi
        case size = "transaction_vsize"
        case type
    }

    let addressees: [String]
    let blockHeight: UInt32
    let canRBF: Bool
    let createdAt: String
    let fee: UInt32
    let feeRate: UInt64
    let hash: String
    let memo: String
    let satoshi: UInt64
    let size: UInt32
    let type: String

    func amount() -> String {
        return String.formatBtc(satoshi: satoshi)
    }

    func address() -> String? {
        guard !addressees.isEmpty else {
            return nil
        }
        return addressees[0]
    }

    func date() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let date = Date.dateFromString(dateString: createdAt)
        return Date.dayMonthYear(date: date)
    }
}

struct Transactions : Codable {

    enum CodingKeys : String, CodingKey {
        case list
        case nextPageId = "next_page_id"
        case pageId = "page_id"
    }

    let list: [TransactionItem]
    let nextPageId: UInt32
    let pageId: UInt32
}

class TransactionsController: UITableViewController {

    var presentingWallet: WalletItem? = nil
    var items: Transactions? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = UINib(nibName: "TransactionTableCell", bundle: nil)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.register(nib, forCellReuseIdentifier: "TransactionTableCell")
        self.tableView.allowsSelection = true
        self.tableView.isUserInteractionEnabled = true
        self.tableView.separatorColor = UIColor.customTitaniumLight()
        tableView.tableHeaderView = getWalletCardView()

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
        if(item.type == "incoming" || item.type == "redeposit") {
            cell.address.text = presentingWallet?.localizedName()
            cell.amount.textColor = UIColor.customMatrixGreen()
        } else {
            cell.address.text = item.address() ?? String()
            cell.amount.textColor = UIColor.white
        }

        if(item.blockHeight == 0) {
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

    func loadTransactions() {
        let bgq = DispatchQueue.global(qos: .background)
        Guarantee().compactMap(on: bgq) {
            try getSession().getTransactions(subaccount: (self.presentingWallet?.pointer)!, page: 0)
        }.compactMap(on: bgq) { data in
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return try JSONDecoder().decode(Transactions.self, from: jsonData)
        }.done { txs in
            self.items = txs
        }.ensure {
            self.tableView.reloadData()
        }.catch { _ in
        }
    }

    func getWalletCardView() -> WalletCardHeader? {
        guard let wallet = presentingWallet else { return nil }

        let view: WalletCardHeader = ((Bundle.main.loadNibNamed("WalletCardHeader", owner: self, options: nil)![0] as? WalletCardHeader)!)

        view.balanceLabel.text = String.formatBtc(satoshi: wallet.satoshi)
        view.addressLabel.text = wallet.getAddress()
        view.nameLabel.text = wallet.localizedName()
        view.index = Int(wallet.pointer)
        view.wallet = wallet
        view.balanceLabel.textColor = UIColor.white
        view.nameLabel.textColor = UIColor.white
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

    func showTransaction(tx: TransactionItem) {
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
            nextController.transaction_g = sender as? TransactionItem
            nextController.pointer = presentingWallet!.pointer
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
