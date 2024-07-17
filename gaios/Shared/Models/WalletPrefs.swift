import UIKit
import core

enum WalletPrefs: Int, CaseIterable {
    case settings
    case createAccount
    case logout
    case denominations
    case rename
    case refresh
    case archive

    enum Sections: Int, CaseIterable {
        case wallet
        case account
        case session

        var name: String {
            switch self {
            case .wallet:
                return "id_wallet".localized.uppercased()
            case .account:
                return "id_account".localized.uppercased()
            case .session:
                return "session".localized.uppercased()
            }
        }
    }

    var name: String {
        switch self {
        case .settings:
            return "id_settings".localized
        case .createAccount:
            return "id_add_new_account".localized
        case .logout:
            return "id_logout".localized
        case .denominations:
            return "Denominations".localized
        case .rename:
            return "id_rename".localized
        case .refresh:
            return "id_refresh".localized
        case .archive:
            return "id_view_archived_accounts".localized
        }
    }

    var icon: UIImage {
        switch self {
        case .settings:
            return UIImage(named: "ic_dialog_gear_six")!
        case .createAccount:
            return UIImage(named: "ic_dialog_simple_plus")!
        case .logout:
            return UIImage(named: "ic_logout")!
        case .denominations:
            return UIImage(named: "ic_dialog_coins")!
        case .rename:
            return UIImage(named: "ic_dialog_rename")!
        case .refresh:
            return UIImage(named: "ic_dialog_refresh")!
        case .archive:
            return UIImage(named: "ic_dialog_archive")!
        }
    }

    static func getPrefs() -> [WalletPrefs] {
        let isWatchOnly = AccountsRepository.shared.current?.isWatchonly ?? false
        let prefs: [WalletPrefs] = isWatchOnly ? [ .settings, .logout ] : [ .createAccount, .settings, .logout ]
        return prefs
    }
    static func getItems() -> [DialogListCellModel] {
        return WalletPrefs.getPrefs().map { DialogListCellModel(type: .list,
                                                                icon: $0.icon,
                                                                title: $0.name) }
    }
    static func groupWalletPrefs() -> ([Int: String], [Int: [WalletPrefs]]) {

        var showArchive = false
        if let subaccount = WalletManager.current?.subaccounts,
           subaccount.filter({ $0.hidden }).count > 0 {
            showArchive = true
        }
        if AccountsRepository.shared.current?.isWatchonly == true {
            return ([0: Sections.wallet.name,
                     1: Sections.session.name],
                    [0: [.denominations, .settings],
                     1: [.refresh, .logout]])
        }
        return ([0: Sections.wallet.name,
                 1: Sections.account.name,
                 2: Sections.session.name],
                [0: [.rename, .denominations, .settings],
                 1: (showArchive ? [.createAccount, .archive] : [.createAccount]),
                 2: [.refresh, .logout]])
    }
    static func getGroupItems() -> ([Int: String], [Int: [DialogGroupListCellModel]]) {
        var groupItems: [Int: [DialogGroupListCellModel]] = [:]
        let groupPrefs = groupWalletPrefs()
        let rows: [Int: [WalletPrefs]] = groupPrefs.1
        var archived = 0
        if let subaccount = WalletManager.current?.subaccounts {
           archived = subaccount.filter({ $0.hidden }).count
        }
        for (k, v) in rows {
            groupItems[k] = v.map { DialogGroupListCellModel(type: .simple,
                                                             icon: $0.icon,
                                                             title: $0.name,
                                                             destructive: $0 == .logout,
                                                             score: (archived > 0 && $0 == .archive) ? archived : nil)
            }
        }
        return (groupPrefs.0, groupItems)
    }
    static func getSelected(_ indexPath: IndexPath) -> WalletPrefs? {
        let groupPrefs = groupWalletPrefs()
        let rows: [Int: [WalletPrefs]] = groupPrefs.1
        if let items = rows[indexPath.section], items.count > 0 {
            return items[indexPath.row]
        }
        return nil
    }
}
