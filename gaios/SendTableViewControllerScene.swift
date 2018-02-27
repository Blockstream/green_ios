//
//  SendTableViewControllerScene.swift
//  gaios
//

import UIKit

enum SendItemType {
    case amount
    case send
}

protocol SendItem {
    var type: SendItemType { get }
    var identifier: String { get }
}

class SendAmountItem: SendItem {
    var type: SendItemType {
        return .amount
    }

    var identifier: String {
        return "SendAmountTableCell"
    }
}

class SendButtonItem: SendItem {
    var type: SendItemType {
        return .send
    }

    var identifier: String {
        return "SendButtonTableCell"
    }
}

class SendTableViewControllerScene: UITableViewController {
    var items = [SendItem]()

    override func viewDidLoad() {
        super.viewDidLoad()

        items.append(SendAmountItem())
        items.append(SendButtonItem())

        tableView.tableFooterView = UIView()
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textAlignment = .center
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Send"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: items[indexPath.row].identifier, for: indexPath)
        return cell
    }
}
