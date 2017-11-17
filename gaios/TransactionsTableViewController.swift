//
//  TransactionsTableViewController.swift
//  gaios
//

import UIKit

class TransactionItem {
    var timestamp: Date
    var address: String
    var amount: String
    var fiatAmount: String

    init(timestamp: Date, address: String, amount: String, fiatAmount: String) {
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

    override init() {
        super.init()

        items.append(TransactionItem(timestamp: Date(), address: "", amount: "", fiatAmount: ""))
    }
}

extension TransactionsTableViewModel: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Transactions"
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
    }
}
