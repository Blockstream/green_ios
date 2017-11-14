//
//  BTCUnitsTableViewController.swift
//  gaios
//

import UIKit

class BTCUnitsTableViewController: UITableViewController {

    let btcUnits: [String] = ["BTC", "mBTC", "uBTC", "bits"]

    var btcUnitsSelected: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BTCUnitsTableCell", for: indexPath)
        cell.textLabel?.text = btcUnits[indexPath.row]
        cell.accessoryType = btcUnitsSelected == indexPath.row ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        cell.accessoryType = .checkmark

        btcUnitsSelected = indexPath.row
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        cell.accessoryType = .none
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == btcUnitsSelected {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
}
