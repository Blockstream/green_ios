//
//  SettingsTableViewController.swift
//  gaios

import UIKit

class SettingsTableViewController: UITableViewController {

    let footerInSection: [Int: String] = [
        0: "Select your pricing source and currency.",
        1: "Notifications allow for improved security when configured for outgoing and for most up to date information when configured for incoming.",
        2: "",
        3: "Create accounts that allow you to separate your funds."
    ]

    func generalCellForRow(_ row: Int, _ cell: UITableViewCell) {
        switch row {
        case 0:
            cell.textLabel!.text = "Pricing Source"
            break
        case 1:
            cell.textLabel!.text = "Currency"
            cell.detailTextLabel!.text = "BTC"
            break
        case 2:
            cell.textLabel!.text = "Sounds"
            break
        default:
            assertionFailure("General: Failed to initialise cell for row \(row)")
        }
    }

    func transactionCellForRow(_ row: Int, _ cell: UITableViewCell) {
        switch row {
        case 0:
            cell.textLabel!.text = "Incoming Notification"
            break
        case 1:
            cell.textLabel!.text = "Outgoing Notification"
            break
        case 2:
            cell.textLabel!.text = "Confirmation Priority"
            cell.detailTextLabel!.text = "Normal"
            break
        case 3:
            cell.textLabel!.text = "nLockTime"
            cell.detailTextLabel!.text = "12960"
            break
        case 4:
            cell.textLabel!.text = "Spending Limits"
            cell.detailTextLabel!.text = "0.00 BTC"
            break
        case 5:
            cell.textLabel!.text = "Increase Fee for Outgoing"
            break
        case 6:
            cell.textLabel!.text = "Segregated Witness"
            break
        default:
            assertionFailure("Transactions: Failed to initialise cell for row \(row)")
        }
    }

    func securityCellForRow(_ row: Int, _ cell: UITableViewCell) {
        switch row {
        case 0:
            cell.textLabel!.text = "Two Factor Authentication"
            cell.detailTextLabel!.text = ""
            break
        default:
            assertionFailure("Security: Failed to initialise cell for row \(row)")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            return 7
        case 2:
            return 1
        default:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "General"
        case 1:
            return "Transactions"
        case 2:
            return "Security"
        case 3:
            return "Accounts"
        default:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return footerInSection[section]
    }

    func cellIdentifierForRowAt(cellForRowAt indexPath: IndexPath) -> String {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 2:
                return "SettingsSwitchTableCell"
            default:
                return "SettingsTableCell"
            }
        case 1:
            switch indexPath.row {
            case 2:
                return "SettingsTableCell"
            case 3:
                return "SettingsTableCell"
            case 4:
                return "SettingsTableCell"
            default:
                return "SettingsSwitchTableCell"
            }
        default:
            return "SettingsTableCell"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifierForRowAt(cellForRowAt: indexPath), for: indexPath)
        switch indexPath.section {
        case 0:
            generalCellForRow(indexPath.row, cell)
            break
        case 1:
            transactionCellForRow(indexPath.row, cell)
            break
        case 2:
            securityCellForRow(indexPath.row, cell)
            break
        default:
            break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            performSegue(withIdentifier: "BTCUnits", sender: self)
            break
        default:
            break
        }
    }
}
