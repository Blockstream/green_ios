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
    case createAccount = "id_create_account"

    var string: String { self.rawValue.localized }
}
struct SettingsItemData {
    var title: String
    var icon: UIImage?
    var subtitle: String
    var attributed: NSMutableAttributedString?
    var section: TabSettingsSection
    var type: SettingsItem
}

class TabSettingsModel {

    // load wallet manager for current logged session
    var wm: WalletManager? { WalletManager.current }

    // load wallet manager for current logged session
    var session: SessionManager? { wm?.prominentSession }
    var settings: Settings? { session?.settings }
    var isWatchonly: Bool { wm?.isWatchonly ?? false }
    var isWatchonlySinglesig: Bool { (wm?.isWatchonly ?? false) && (wm?.account.username?.isEmpty ?? true) }
    var isSinglesig: Bool { session?.gdkNetwork.electrum ?? true }
    var isHW: Bool { wm?.account.isHW ?? false }
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
            title: "id_settings".localized,
            subtitle: "",
            section: .header,
            type: .header)
        return [header]
    }
    func getWallet() -> [SettingsItemData] {
        guard let settings = settings, let session = session else { return [] }
        let network: NetworkSecurityCase = session.gdkNetwork.mainnet ? .bitcoinSS : .testnetSS
        let rename = SettingsItemData(
            title: "\("id_rename".localized)",
            subtitle: "\(AccountsRepository.shared.current?.name ?? "")",
            section: .wallet,
            type: .rename)
        let unifiedDenominationExchange = SettingsItemData(
            title: SettingsItem.unifiedDenominationExchange.string,
            subtitle: "",
            attributed: getDenominationExchangeInfo(settings: settings, network: network),
            section: .wallet,
            type: .unifiedDenominationExchange)
        let autolock = SettingsItemData(
            title: SettingsItem.autoLogout.string,
            subtitle: (settings.autolock).string,
            section: .wallet,
            type: .autoLogout)
        let logout = SettingsItemData(
            title: "id_log_out".localized,
            icon: UIImage(named: "ic_logout"),
            subtitle: "",
            section: .wallet,
            type: .logout)
        var menu = [SettingsItemData]()
        menu += [rename, unifiedDenominationExchange, autolock, logout]
        return menu
    }
    func getAccount() -> [SettingsItemData] {
        let lightning = SettingsItemData(
            title: SettingsItem.lightning.string,
            subtitle: "",
            section: .account,
            type: .lightning)
        let ampID = SettingsItemData(
            title: SettingsItem.ampID.string,
            subtitle: "",
            section: .account,
            type: .ampID)
        let twoFactorAuth = SettingsItemData(
            title: SettingsItem.twoFactorAuthication.string,
            subtitle: "",
            section: .account,
            type: .twoFactorAuthication)
        let pgpKey = SettingsItemData(
            title: SettingsItem.pgpKey.string,
            subtitle: "",
            section: .account,
            type: .pgpKey)
        let watchOnly = SettingsItemData(
            title: SettingsItem.watchOnly.string,
            subtitle: "",
            section: .account,
            type: .watchOnly)
        let archievedAccounts = SettingsItemData(
            title: SettingsItem.archievedAccounts.string,
            subtitle: "",
            section: .account,
            type: .archievedAccounts)
        let createAccount = SettingsItemData(
            title: SettingsItem.createAccount.string,
            subtitle: "",
            section: .account,
            type: .createAccount)
        var menu = [SettingsItemData]()
        if !isWatchonly && AppSettings.shared.experimental {
            menu += [lightning]
        }
        if !isWatchonlySinglesig {
            menu += [ampID]
        }
        if !isWatchonly && wm?.hasMultisig ?? false {
            menu += [twoFactorAuth, pgpKey]
        }
        if !isWatchonly {
            menu += [watchOnly, archievedAccounts] // , createAccount]
        }
        return menu
    }
    func getAbout() -> [SettingsItemData] {
        let version = SettingsItemData(
            title: SettingsItem.version.string,
            subtitle: Common.versionNumber,
            section: .about,
            type: .version)
        let supportId = SettingsItemData(
            title: SettingsItem.supportID.string,
            icon: UIImage(named: "ic_copy_small"),
            subtitle: "id_copy_support_id".localized,
            section: .about,
            type: .supportID)
        return [version, supportId]
    }
    func getSupport() -> [SettingsItemData] {
        let support = SettingsItemData(
            title: SettingsItem.support.string,
            icon: UIImage(named: "ic_contact_support"),
            subtitle: "",
            section: .support,
            type: .support)
        var menu = [SettingsItemData]()
        menu += [support]
        return menu
    }
    func load() {
        if isWatchonly {
            sections = [.header, .wallet, .about, .support ]
                items = [.header: getHeader(), .wallet: getWallet(), .about: getAbout(), .support: getSupport()]
        } else {
            sections = [.header, .wallet, .account, .about, .support ]
                items = [.header: getHeader(), .wallet: getWallet(), .account: getAccount(), .about: getAbout(), .support: getSupport()]
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
            throw GaError.GenericError("id_invalid_session".localized)
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
            title: "id_account_selector".localized,
            hint: "id_select_an_account_to_get_the".localized,
            isSelectable: true,
            assetId: nil,
            accounts: getSubaccountsAmp(),
            hideBalance: false)
    }
    func hasLightning() -> Bool {
        guard let account = WalletManager.current?.account else {
            return false
        }
        return AuthenticationTypeHandler.findAuth(
            method: .AuthKeyLightning,
            forNetwork: account.keychainLightning)
    }
}
