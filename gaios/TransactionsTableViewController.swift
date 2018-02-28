//
//  TransactionsTableViewController.swift
//  gaios
//

import PromiseKit

import UIKit

class TransactionItem {
    var timestamp: String
    var address: String
    var amount: String
    var fiatAmount: String

    init(timestamp: String, address: String, amount: String, fiatAmount: String) {
        self.timestamp = timestamp
        self.address = address
        self.amount = amount
        self.fiatAmount = fiatAmount
    }
}

class TransactionCell: UITableViewCell {
    @IBOutlet weak var timestamp: UILabel!
    @IBOutlet weak var address: UILabel!
    @IBOutlet weak var amount: UILabel!
    @IBOutlet weak var fiatAmount: UILabel!

    var item: TransactionItem? {
        didSet {
            guard let item = item else {
                return
            }

            timestamp.text = item.timestamp.description
            address.text = item.address
            amount.text = item.amount
            fiatAmount.text = item.fiatAmount
        }
    }
}

class TransactionsTableViewModel: NSObject {
    var items = [TransactionItem]()

    func getTransactions() -> Promise<[Transaction]?> {
        return retry(session: getSession(), network: Network.TestNet) {
            return wrap { return try getSession().getTransactions(subaccount: 0) }
        }
    }

    override init() {
        super.init()
    }

    func dateFromTimestamp(date: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: date)!
    }

    func updateViewModel(tableView: UITableView) {
        getTransactions().then { (txs: [Transaction]?) -> Void in
            self.items.removeAll(keepingCapacity: true)
            for tx in txs ?? [] {
                let json = try! tx.toJSON()!
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                let date = dateFormatter.string(from: self.dateFromTimestamp(date: json["timestamp"] as! String))
                self.items.append(TransactionItem(timestamp: date, address: "", amount: String(json["value"] as! Int64), fiatAmount: ""))
            }
        }.always {
            tableView.reloadData()
        }
    }
}

extension TransactionsTableViewModel: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if items.count != 0 {
            return 1
        }
        else {
            let label: UILabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.bounds.size.height))
            label.text = "You don't have any items right now"
            label.textAlignment = .center
            tableView.backgroundView = label
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Main"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TransactionTableCell", for: indexPath) as! TransactionCell
        cell.item = items[indexPath.row]
        return cell
    }
}

class TransactionsTableViewController: UITableViewController {
    fileprivate let viewModel = TransactionsTableViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = viewModel

        tableView.tableFooterView = UIView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        viewModel.updateViewModel(tableView: self.tableView)
    }
}
