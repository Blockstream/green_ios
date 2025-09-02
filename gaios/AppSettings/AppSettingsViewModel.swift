import UIKit
import core
enum AppSettingsSection: Int, CaseIterable {
    case header
    case generic
    case server
    case limit
}
enum AppSettingsCellType {
    case title
    case tor
    case proxy
    case proxyEdit
    case hw
    case testnet
    case help
    case experimental
    case language
    case meld
    case electrum
    case electrumEdit
    case addresses
}
class AppSettingsViewModel {

    let appSettings = AppSettings.shared
    let gdkSettings: GdkSettings? = AppSettings.shared.gdkSettings
    var sections: [AppSettingsSection] {
        let list: [AppSettingsSection] = [.header, .generic, .server, .limit]
        return list
    }
    func cellItems(_ section: AppSettingsSection) -> [AppSettingsCellType] {
        switch section {
        case .header:
            var items = [AppSettingsCellType]()
            items.append(.title)
            return items
        case .generic:
            var items = [AppSettingsCellType]()
            items.append(.tor)
            items.append(.proxy)
            if isProxyOn { items.append(.proxyEdit) }
            items.append(.hw)
            items.append(.testnet)
            items.append(.help)
            items.append(.experimental)
            items.append(.language)
            if Bundle.main.dev { items.append(.meld) }
            return items
        case .server:
            var items = [AppSettingsCellType]()
            items.append(.electrum)
            if isElectrumOn { items.append(.electrumEdit) }
            return items
        case .limit:
            return [.addresses]
        }
    }
    var isTorOn: Bool
    var isHWOn: Bool
    var isProxyOn: Bool
    var proxyAddress: String?
    var isTestnetOn: Bool
    var isAnalyticsOn: Bool
    var isExperimentalOn: Bool
    var isMeldOn: Bool
    var isElectrumOn: Bool
    var isTlsOn: Bool
    var serverBTC: String?
    var serverLiquid: String?
    var serverTestnet: String?
    var serverLiquidtestnet: String?
    var gapLimit: Int?

    init() {
        self.isTorOn = gdkSettings?.tor ?? false
        self.isHWOn = !appSettings.rememberHWIsOff
        self.isTestnetOn = appSettings.testnet
        self.isProxyOn = gdkSettings?.proxy ?? false
        if let socks5 = gdkSettings?.socks5Hostname,
           let port = gdkSettings?.socks5Port,
           !socks5.isEmpty && !port.isEmpty {
            self.proxyAddress = "\(socks5):\(port)"
        }
        self.isAnalyticsOn = AnalyticsManager.shared.consent == .authorized
        self.isExperimentalOn = appSettings.experimental
        self.isMeldOn = Meld.isSandboxEnvironment
        self.isElectrumOn = gdkSettings?.personalNodeEnabled ?? false
        self.isTlsOn = gdkSettings?.electrumTls ?? false

        if let uri = gdkSettings?.btcElectrumSrv, !uri.isEmpty {self.serverBTC = uri}
        if let uri = gdkSettings?.liquidElectrumSrv, !uri.isEmpty {self.serverLiquid = uri}
        if let uri = gdkSettings?.testnetElectrumSrv, !uri.isEmpty {self.serverTestnet = uri}
        if let uri = gdkSettings?.liquidTestnetElectrumSrv, !uri.isEmpty {self.serverLiquidtestnet = uri}
        if let gap = gdkSettings?.gapLimit {self.gapLimit = gap}
    }
    func getProxyAddress() -> String {
        if let socks5 = gdkSettings?.socks5Hostname,
           let port = gdkSettings?.socks5Port,
           !socks5.isEmpty && !port.isEmpty {
            return "\(socks5):\(port)"
        } else {
            return ""
        }
    }
    var electrumCellModel: ElectrumCellModel {
        return ElectrumCellModel(switchTls: gdkSettings?.electrumTls ?? true,
                                 serverBTC: self.serverBTC ?? "",
                                 serverLiquid: self.serverLiquid ?? "",
                                 serverTestnet: self.serverTestnet ?? "",
                                 serverLiquidtestnet: self.serverLiquidtestnet ?? "")
    }
}
