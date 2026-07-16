import Foundation

import hw

public extension AnalyticsManager {

    typealias Sgmt = [String: String]

    func ntwSgmtUnified() -> Sgmt {
        var s = Sgmt()
        if let analyticsNtw = analyticsNetworks {
            s[AnalyticsManager.strNetworks] = analyticsNtw.rawValue
        }
        if let analyticsSec = analyticsSecurity {
            s[AnalyticsManager.strSecurity] = analyticsSec.map { $0.rawValue }.joined(separator: "-")
        }
        return s
    }

    func onBoardSgmtUnified(flow: AnalyticsManager.OnBoardFlow) -> Sgmt {
        var s = Sgmt()
        s[AnalyticsManager.strFlow] = flow.rawValue
        return s
    }

    func sessSgmt(_ wallet: Wallet?) -> Sgmt {
        var s = ntwSgmtUnified()
        if wallet?.isJade ?? false {
            s[AnalyticsManager.strBrand] = "Blockstream"
            s[AnalyticsManager.strFirmware] = hwData.fwVersion
            s[AnalyticsManager.strModel] = hwData.model
            s[AnalyticsManager.strConnection] = AnalyticsManager.strBle
        }
        if wallet?.isLedger ?? false {
            s[AnalyticsManager.strBrand] = "Ledger"
            s[AnalyticsManager.strFirmware] = hwData.fwVersion
            s[AnalyticsManager.strModel] = "Ledger Nano X"
            s[AnalyticsManager.strConnection] = AnalyticsManager.strBle
        }
        s[AnalyticsManager.strAppSettings] = appSettings()
        return s
    }

    func walletNetworkLabel(_ gdkNetwork: GdkNetwork) -> String {
        let server: String? = {
            if gdkNetwork.lightning { return "greenlight" }
            if gdkNetwork.multisig { return "legacy" }
            if gdkNetwork.singlesig { return "electrum" }
            return nil
        }()
        let liquid = gdkNetwork.liquid ? "liquid" : nil
        let mainnet = gdkNetwork.liquid && gdkNetwork.mainnet ? nil : gdkNetwork.mainnet ? "mainnet" : "testnet"
        return [server, liquid, mainnet].compactMap { $0 }.joined(separator: "-")
    }

    func subAccSeg(_ wallet: Wallet?, account: Account?) -> Sgmt {
        var s = sessSgmt(wallet)
        if let account {
            s[AnalyticsManager.strAccountType] = account.type.rawValue
            s[AnalyticsManager.strNetwork] = walletNetworkLabel(account.gdkNetwork)
        }
        return s
    }

    func twoFacSgmt(_ wallet: Wallet?, account: Account?, twoFactorType: TwoFactorType?) -> Sgmt {
        var s = subAccSeg(wallet, account: account)
        if let twoFactorType = twoFactorType, let account {
            s[AnalyticsManager.str2fa] = twoFactorType.rawValue
            s[AnalyticsManager.strNetwork] = walletNetworkLabel(account.gdkNetwork)
        }
        return s
    }

    func firmwareSgmt(_ wallet: Wallet?, firmware: Firmware) -> Sgmt {
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strSelectedConfig] = firmware.config.lowercased()
        s[AnalyticsManager.strSelectedDelta] = firmware.isDelta == true ? "true" : "false"
        s[AnalyticsManager.strSelectedVersion] = firmware.version
        return s
    }

    func swapSgmt(_ wallet: Wallet?, from: String, to: String) -> Sgmt {
        var s = sessSgmt(wallet)
        s[AnalyticsManager.strSwapFrom] = from
        s[AnalyticsManager.strSwapTo] = to
        return s
    }

    func appSettings() -> String {
        let settings = GdkSettings.read()
        var settingsProps: [String] = []
        if settings?.proxy ?? false == true {
            settingsProps.append(AnalyticsManager.strProxy)
        }
        if settings?.tor ?? false == true {
            settingsProps.append(AnalyticsManager.strTor)
        }
        if AppSettings.shared.testnet {
            settingsProps.append(AnalyticsManager.strTestnet)
        }
        if settings?.personalNodeEnabled ?? false == true {
            settingsProps.append(AnalyticsManager.strElectrumServer)
        }
        if settingsProps.count == 0 {
            return ""
        }
        return settingsProps.sorted().joined(separator: ",")
    }
}
