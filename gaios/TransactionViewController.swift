import Foundation
import UIKit
import PromiseKit


class TransactionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    var items = [NotificationItem]()
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateViewModel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "NotificationTableCell", bundle: nil)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(nib, forCellReuseIdentifier: "NotificationCell")
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.customTitaniumLight()
        tableView.tableHeaderView = headerView
        updateViewModel()
        NotificationStore.shared.refreshNotifications = {
            self.updateViewModel()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationChanged(_:)), name: NSNotification.Name(rawValue: "notificationChanged"), object: nil)
        titleLabel.text = NSLocalizedString("id_notifications", comment: "")
        NotificationStore.shared.refreshWarning()
    }

    @objc func notificationChanged(_ notification: NSNotification) {
        updateViewModel()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let item = items[indexPath.row]
        let widthContraint = self.tableView.frame.size.width - 84
        let height = item.text.heightWithConstrainedWidth(width: widthContraint, font: UIFont.systemFont(ofSize: 12, weight: .light))
        let total = 88 + height + 40
        return total
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as! NotificationTableCell
        let item: NotificationItem = items.reversed()[indexPath.row]
        cell.mainText.text = item.text
        if(item.isWarning) {
            cell.title.textColor = UIColor.red
        } else {
            cell.title.textColor = UIColor.white
        }
        cell.title.text = item.title
        cell.date.text = NotificationStore.shared.dateToText(date: item.date)
        cell.date.sizeToFit()
        cell.title.sizeToFit()
        NotificationStore.shared.setSeen(id: item.id)
        cell.separatorInset = UIEdgeInsetsMake(0, 42, 0, 16)
        return cell;

    }

    func updateViewModel() {
        items = NotificationStore.shared.getNotifications()
        tableView.reloadData()
    }
}

class TransactionItem {
    var timestamp: String
    var address: String
    var amount: String
    var fiatAmount: String
    var date: String
    var btc_amount: Double
    var type: String
    var hash: String
    var blockheight: UInt32
    var fee: UInt32
    var size: UInt32
    var memo: String
    var dateRaw: Date
    var canRBF: Bool
    var rawTransaction: [String: Any]

    init(timestamp: String, address: String, amount: String, fiatAmount: String, date: String, btc: Double, type: String, hash: String, blockheight: UInt32, fee: UInt32, size: UInt32, memo: String, dateRaw: Date, canRBF: Bool, rawTransaction: [String: Any]) {
        self.timestamp = timestamp
        self.address = address
        self.amount = amount
        self.fiatAmount = fiatAmount
        self.date = date
        self.btc_amount = btc
        self.type = type
        self.hash = hash
        self.blockheight = blockheight
        self.fee = fee
        self.size = size
        self.memo = memo
        self.dateRaw = dateRaw
        self.canRBF = canRBF
        self.rawTransaction = rawTransaction
    }
}
