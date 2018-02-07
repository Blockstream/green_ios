//
//  SettingsTableViewController.swift
//  gaios

import UIKit

enum SettingsItemType {
    case selector
    case switcher
}

protocol SettingsItem {
    var type: SettingsItemType { get }
    var identifier: String { get }
    var segueIdentifier: String? { get }
    var text: String { get }
    var detailText: String? { get }
    var on: Bool? { get }
}

extension SettingsItem {
    var segueIdentifier: String? {
        return nil
    }

    var detailText: String? {
        return nil
    }

    var on: Bool? {
        return nil
    }
}

class GenericSettingsItem: SettingsItem {
    var type: SettingsItemType
    var identifier: String
    var segueIdentifier: String?
    var text: String
    var detailText: String?
    var on: Bool?

    init(type: SettingsItemType, identifier: String, segueIdentifier: String?, text: String, detailText: String?, on: Bool?) {
        self.type = type
        self.identifier = identifier
        self.segueIdentifier = segueIdentifier
        self.text = text
        self.detailText = detailText
        self.on = on
    }
}

class GenericSelectorSettingsItem: GenericSettingsItem {
    init(text: String, detailText: String, show segueIdentifier: String) {
        super.init(type: .selector, identifier: "SettingsTableCell", segueIdentifier: segueIdentifier, text: text, detailText: detailText, on: nil)
    }
}

class GenericSwitcherSettingsItem: GenericSettingsItem {
    init(text: String, on: Bool) {
        super.init(type: .switcher, identifier: "SettingsSwitchTableCell", segueIdentifier: nil, text: text, detailText: nil, on: on)
    }
}

class PricingSourceItem: GenericSelectorSettingsItem {
    init(detailText: String, show segueIdentifier: String) {
        super.init(text: "Pricing Source", detailText: detailText, show: segueIdentifier)
    }
}

class CurrencyItem: GenericSelectorSettingsItem {
    init(detailText: String, show segueIdentifier: String) {
        super.init(text: "Currency", detailText: detailText, show: segueIdentifier)
    }
}

class IncomingNotificationItem: GenericSwitcherSettingsItem {
    init(on: Bool) {
        super.init(text: "Incoming Notification", on: on)
    }
}

class OutgoingNotificationItem: GenericSwitcherSettingsItem {
    init(on: Bool) {
        super.init(text: "Outgoing Notification", on: on)
    }
}

class ConfirmationPriorityItem: GenericSelectorSettingsItem {
    init(detailText: String, show segueIdentifier: String) {
        super.init(text: "ConfirmationPriority", detailText: detailText, show: segueIdentifier)
    }
}

class NLockTimeItem: GenericSelectorSettingsItem {
    init(detailText: String, show segueIdentifier: String) {
        super.init(text: "nLockTime", detailText: detailText, show: segueIdentifier)
    }
}

class SpendingLimitsItem: GenericSelectorSettingsItem {
    init(detailText: String, show segueIdentifier: String) {
        super.init(text: "Spending Limits", detailText: detailText, show: segueIdentifier)
    }
}

class IncreaseFeeForOutgoingItem: GenericSwitcherSettingsItem {
    init(on: Bool) {
        super.init(text: "Increase Fee for Outgoing", on: on)
    }
}

class SegregatedWitnessItem: GenericSwitcherSettingsItem {
    init(on: Bool) {
        super.init(text: "Segregated Witness", on: on)
    }
}

class TwoFactorAuthenticationItem: GenericSelectorSettingsItem {
    init(detailText: String, show segueIdentifier: String) {
        super.init(text: "Two Factor Authentication", detailText: detailText, show: segueIdentifier)
    }
}

class AccountsItem: GenericSelectorSettingsItem {
    init(detailText: String, show segueIdentifier: String) {
        super.init(text: "Accounts", detailText: detailText, show: segueIdentifier)
    }
}

enum SettingsSectionItemType {
    case general
    case transactions
    case security
    case accounts
}

protocol SettingsSectionItem {
    var type: SettingsSectionItemType { get }
    var rowCount: Int { get }
    var sectionTitle: String { get }
    var sectionFooter: String { get }
    var items: [SettingsItem] { get }
}

class GeneralSettingsSection: SettingsSectionItem {
    var type: SettingsSectionItemType {
        return .general
    }

    var rowCount: Int {
        return items.count
    }

    var sectionTitle: String {
        return "General"
    }

    var sectionFooter: String {
        return "Select your pricing source and currency."
    }

    var items = [SettingsItem]()
}

class TransactionsSettingsSection: SettingsSectionItem {
    var type: SettingsSectionItemType {
        return .transactions
    }

    var rowCount: Int {
        return items.count
    }

    var sectionTitle: String {
        return "Transactions"
    }

    var sectionFooter: String {
        return "Notifications allow for improved security when configured for outgoing and for most up to date information when configured for incoming."
    }

    var items = [SettingsItem]()
}

class SecuritySettingsSection: SettingsSectionItem {
    var type: SettingsSectionItemType {
        return .security
    }

    var rowCount: Int {
        return items.count
    }

    var sectionTitle: String {
        return "Security"
    }

    var sectionFooter: String {
        return ""
    }

    var items = [SettingsItem]()
}

class AccountSettingsSection: SettingsSectionItem {
    var type: SettingsSectionItemType {
        return .accounts
    }

    var rowCount: Int {
        return items.count
    }

    var sectionTitle: String {
        return "Accounts"
    }

    var sectionFooter: String {
        return "Create accounts that allow you to separate your funds."
    }

    var items = [SettingsItem]()
}

class SelectorCell: UITableViewCell {

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var detail: UILabel!

    var item: SettingsItem? {
        didSet {
            guard  let item = item as? GenericSettingsItem else {
                return
            }

            self.title.text = item.text
            self.detail.text = item.detailText
        }
    }
}

class SwitcherCell: UITableViewCell {

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var on: UISwitch!

    var item: SettingsItem? {
        didSet {
            guard let item = item as? GenericSettingsItem else {
                return
            }

            self.title.text = item.text
            self.on.isOn = item.on!
        }
    }
}

class SettingsTableViewModel: NSObject {
    var sections = [SettingsSectionItem]()

    override init() {
        super.init()

        let loginData = getGAService().loginData!

        let generalSection = GeneralSettingsSection()
        generalSection.items.append(PricingSourceItem(detailText: loginData["exchange"] as? String ?? "BITSTAMP", show: ""))
        generalSection.items.append(CurrencyItem(detailText: (loginData["appearance"] as! [String: Any])["unit"] as? String ?? "BTC", show: ""))
        sections.append(generalSection)

        let transactionsSection = TransactionsSettingsSection()
        transactionsSection.items.append(IncomingNotificationItem(on: false))
        transactionsSection.items.append(OutgoingNotificationItem(on: false))
        transactionsSection.items.append(ConfirmationPriorityItem(detailText: "Economy", show: ""))
        transactionsSection.items.append(NLockTimeItem(detailText: "12960", show: ""))
        transactionsSection.items.append(SpendingLimitsItem(detailText: "0.00", show: ""))
        transactionsSection.items.append(IncreaseFeeForOutgoingItem(on: (loginData["appearance"] as! [String: Any])["replace_by_fee"] as? Bool ?? false))
        transactionsSection.items.append(SegregatedWitnessItem(on: (loginData["appearance"] as! [String: Any])["use_segwit"] as? Bool ?? false))
        sections.append(transactionsSection)

        let securitySection = SecuritySettingsSection()
        securitySection.items.append(TwoFactorAuthenticationItem(detailText: "", show: ""))
        sections.append(securitySection)

        let accountSection = AccountSettingsSection()
        accountSection.items.append(AccountsItem(detailText: "", show: ""))
        sections.append(accountSection)
    }
}

extension SettingsTableViewModel: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].sectionTitle
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rowCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]
        switch item.type {
        case .selector:
            let cell = tableView.dequeueReusableCell(withIdentifier: item.identifier, for: indexPath) as! SelectorCell
            cell.item = item
            return cell

        case .switcher:
            let cell = tableView.dequeueReusableCell(withIdentifier: item.identifier, for: indexPath) as! SwitcherCell
            cell.item = item
            return cell
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].sectionFooter
    }
}

class SettingsTableViewController: UITableViewController {
    fileprivate let viewModel = SettingsTableViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = viewModel

        tableView.tableFooterView = UIView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}
