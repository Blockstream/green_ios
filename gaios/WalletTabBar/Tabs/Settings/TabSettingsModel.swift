import Foundation
import UIKit
import core
import gdk
import greenaddress

enum SettingsItem: String, Codable, CaseIterable {
    case header = "id_header"
    case logout = "id_logout"
    case unifiedDenominationExchange = "id_denomination__exchange_rate"
    case support = "id_support"
    case archievedAccounts = "id_archived_accounts"
    case watchOnly = "Wallet Details"
    case twoFactorAuthication = "id_twofactor_authentication"
    case pgpKey = "id_pgp_key"
    case autoLogout = "id_auto_logout_timeout"
    case version = "id_version"
    case supportID = "Support ID"
    case rename = "id_rename_wallet"
    case lightning = "id_lightning"
    case ampID = "id_amp_id"

    var string: String { self.rawValue.localized }
}
struct SettingsItemData {
    var title: String
    var subtitle: String
    var attributed: NSMutableAttributedString?
    var section: TabSettingsSection
    var type: SettingsItem
    var switcher: Bool?
}

class TabSettingsModel {

    // load wallet manager for current logged session
    var wm: WalletManager? { WalletManager.current }

    // load wallet manager for current logged session
    var session: SessionManager? { wm?.prominentSession }
    var settings: Settings? { session?.settings }
    var isWatchonly: Bool { wm?.account.isWatchonly ?? false }
    var isWatchonlySinglesig: Bool { (wm?.account.isWatchonly ?? false) && (wm?.account.username?.isEmpty ?? true) }
    var isSinglesig: Bool { session?.gdkNetwork.electrum ?? true }
    var isHW: Bool { wm?.account.isHW ?? false }
    var isDerivedLightning: Bool { wm?.account.isDerivedLightning ?? false }
    var multiSigSession: SessionManager? { wm?.activeSessions.values.filter { !$0.gdkNetwork.electrum }.first }

    // reload all contents
    var reloadTableView: (() -> Void)?

    // settings cell models
    var sections = [TabSettingsSection]()
    var items = [TabSettingsSection: [SettingsItemData]]()
    var cellModels = [TabSettingsSection: [TabSettingsCellModel]]() {
        didSet {
            reloadTableView?()
        }
    }

    func getCellModel(at indexPath: IndexPath) -> TabSettingsCellModel? {
        // da cambiare in SettingsCellModel visto che è cambiata la cella
        let section = sections[indexPath.section]
        return cellModels[section]?[indexPath.row]
    }

    func getCellModelsForSection(at indexSection: Int) -> [TabSettingsCellModel]? {
        let section = sections[indexSection]
        return cellModels[section]
    }

    func getHeader() -> [SettingsItemData] {
        let header = SettingsItemData(
            title: "Settings",
            subtitle: "",
            section: .header,
            type: .header)
        return [header]
    }
    func getGeneral() -> [SettingsItemData] {
        guard let settings = settings, let session = session else { return [] }
        let network: NetworkSecurityCase = session.gdkNetwork.mainnet ? .bitcoinSS : .testnetSS

        let support = SettingsItemData(
            title: SettingsItem.support.string,
            subtitle: "",
            section: .general,
            type: .support)
        let unifiedDenominationExchange = SettingsItemData(
            title: SettingsItem.unifiedDenominationExchange.string,
            subtitle: "",
            attributed: getDenominationExchangeInfo(settings: settings, network: network),
            section: .general,
            type: .unifiedDenominationExchange)
        let autolock = SettingsItemData(
            title: SettingsItem.autoLogout.string,
            subtitle: (settings.autolock).string,
            section: .general,
            type: .autoLogout)
        let logout = SettingsItemData(
            title: wm?.account.name.localizedCapitalized ?? "",
            subtitle: "id_log_out".localized,
            section: .general,
            type: .logout)
        var menu = [SettingsItemData]()
        menu += [support, unifiedDenominationExchange, autolock, logout]
        return menu
    }
    func getWallet() -> [SettingsItemData] {
        let lightning = SettingsItemData(
            title: SettingsItem.lightning.string,
            subtitle: "",
            section: .wallet,
            type: .lightning)
        let ampID = SettingsItemData(
            title: SettingsItem.ampID.string,
            subtitle: "",
            section: .wallet,
            type: .ampID)
        let watchOnly = SettingsItemData(
            title: SettingsItem.watchOnly.string,
            subtitle: "",
            section: .wallet,
            type: .watchOnly)
        let rename = SettingsItemData(
            title: SettingsItem.rename.string,
            subtitle: "",
            section: .wallet,
            type: .rename)

        var archived = 0
        if let subaccount = WalletManager.current?.subaccounts {
            archived = subaccount.filter({ $0.hidden }).count
        }
        let archievedAccounts = SettingsItemData(
            title: SettingsItem.archievedAccounts.string,
            subtitle: "", // archived == 0 ? "" : String(archived),
            section: .wallet,
            type: .archievedAccounts)
        var menu = [SettingsItemData]()
        if !isWatchonly {
            menu += [lightning]
        }
        if !isWatchonlySinglesig {
            menu += [ampID]
        }
        if !isDerivedLightning && !isWatchonly {
            menu += [watchOnly]
        }
        menu += [rename]

        if archived > 0 {
            menu += [archievedAccounts]
        }
        return menu
    }
    func getTwoFactor() -> [SettingsItemData] {
        var menu = [SettingsItemData]()
        let twoFactorAuth = SettingsItemData(
            title: SettingsItem.twoFactorAuthication.string,
            subtitle: "",
            section: .general,
            type: .twoFactorAuthication)
        let pgpKey = SettingsItemData(
            title: SettingsItem.pgpKey.string,
            subtitle: "",
            section: .general,
            type: .pgpKey)
        if !isWatchonly && wm?.hasMultisig ?? false {
            menu += [twoFactorAuth, pgpKey]
        }
        return menu
    }
    func getAbout() -> [SettingsItemData] {
        let version = SettingsItemData(
            title: SettingsItem.version.string,
            subtitle: Common.versionString,
            section: .about,
            type: .version)
        let support = SettingsItemData(
            title: SettingsItem.supportID.string,
            subtitle: "id_copy_support_id".localized,
            section: .about,
            type: .supportID)
        if multiSigSession != nil {
            return [version, support]
        }
        return [version]
    }

    func load() {
        if isDerivedLightning {
            sections = [.header, .general, .wallet, .twoFactor, .about ]
            items = [.header: getHeader(), .general: getGeneral(), .wallet: getWallet(), .twoFactor: getTwoFactor(), .about: getAbout()]
        } else if isWatchonly || isHW {
            sections = [.header, .general, .wallet, .about ]
            items = [.header: getHeader(), .general: getGeneral(), .wallet: getWallet(), .about: getAbout()]
        } else {
            if wm?.hasMultisig ?? false == false {
                sections = [.header, .general, .wallet, .about ]
                items = [.header: getHeader(), .general: getGeneral(), .wallet: getWallet(), .about: getAbout()]
            } else {
                sections = [.header, .general, .wallet, .twoFactor, .about ]
                items = [.header: getHeader(), .general: getGeneral(), .wallet: getWallet(), .twoFactor: getTwoFactor(), .about: getAbout()]
            }
        }
        cellModels = items.mapValues { $0.map { TabSettingsCellModel($0) } }
    }

    func getDenominationExchangeInfo(settings: Settings, network: NetworkSecurityCase) -> NSMutableAttributedString {
        let den = settings.denomination.string(for: network.gdkNetwork)
        let pricing = settings.pricing["currency"] ?? ""
        let exchange = (settings.pricing["exchange"] ?? "").uppercased()
        let plain = "Display values in \(den) and exchange rate in \(pricing) using \(exchange)"
        let iAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gAccent()
        ]
        let attrStr = NSMutableAttributedString(string: plain)
        attrStr.setAttributes(iAttr, for: den)
        attrStr.setAttributes(iAttr, for: pricing)
        attrStr.setAttributes(iAttr, for: exchange)
        return attrStr
    }

    func hasSubaccountAmp() -> Bool {
        !getSubaccountsAmp().isEmpty
    }

    func getSubaccountsAmp() -> [WalletItem] {
        wm?.subaccounts.filter({ $0.type == .amp }) ?? []
    }

    func createSubaccountAmp() async throws {
        guard let session = wm?.liquidMultisigSession else {
            throw GaError.GenericError("Invalid session".localized)
        }
        try await session.connect()
        if !session.logged {
            if let device = wm?.hwDevice {
                try await session.register(credentials: nil, hw: device)
                _ = try await session.loginUser(credentials: nil, hw: device)
            } else {
                let credentials = try await wm?.prominentSession?.getCredentials(password: "")
                try await session.register(credentials: credentials, hw: nil)
                _ = try await session.loginUser(credentials: credentials, hw: nil)
            }
        }
        _ = try await session.createSubaccount(CreateSubaccountParams(name: uniqueAmpName(), type: .amp))
        _ = try await session.updateSubaccount(UpdateSubaccountParams(subaccount: 0, hidden: false))
        _ = try await wm?.subaccounts()
    }

    func uniqueAmpName() -> String {
        let counter = wm?.subaccounts.filter({ $0.type == .amp && $0.gdkNetwork.liquid }).count ?? 0
        if counter > 0 {
            return "Liquid AMP \(counter+1)"
        }
        return "Liquid AMP"
    }

    func dialogAccountsModel() -> DialogAccountsViewModel {
        return DialogAccountsViewModel(
            title: "Account Selector",
            hint: "Select the desired account you want to get AMP ID.".localized,
            isSelectable: true,
            assetId: nil,
            accounts: getSubaccountsAmp(),
            hideBalance: false)
    }
}
