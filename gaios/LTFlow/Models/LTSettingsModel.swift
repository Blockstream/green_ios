import Foundation
import gdk
import core

enum LTSettingsCellType: CaseIterable {
    case id
    case channelsBalance
    case inboundLiquidity
    case maxPayble
    case maxSinglePaymentAmount
    case maxReceivable
    case onchainBalanceSatoshi
    case blockHeight
}

struct LTSettingsViewModel {

    var lightningSession: LightningSessionManager

    var cellTypes: [LTSettingsCellType] {
        return LTSettingsCellType.allCases
    }
    func cellModelByType(_ cellType: LTSettingsCellType) -> LTSettingCellModel {
        switch cellType {
        case .id:
            return LTSettingCellModel(
                title: "ID",
                subtitle: nil,
                value: "\(id.prefix(8))...\(id.suffix(8))",
                hiddenIcon: false)
        case .channelsBalance:
            return LTSettingCellModel(
                title: "id_account_balance".localized,
                subtitle: nil,
                value: channelsBalanceText,
                hiddenIcon: true)
        case .inboundLiquidity:
            return LTSettingCellModel(
                title: "Inbound Liquidity".localized,
                subtitle: nil,
                value: inboundLiquidity,
                hiddenIcon: true)
        case .maxPayble:
            return LTSettingCellModel(
                title: "Max Payable Amount".localized,
                subtitle: nil,
                value: maxPayble,
                hiddenIcon: true)
        case .maxSinglePaymentAmount:
            return LTSettingCellModel(
                title: "Max Payment Amount".localized,
                subtitle: "Single",
                value: maxSinglePaymentAmount,
                hiddenIcon: true)
        case .maxReceivable:
            return LTSettingCellModel(
                title: "Max Receivable Amount".localized,
                subtitle: nil,
                value: maxReceivable,
                hiddenIcon: true)
        case .onchainBalanceSatoshi:
            return LTSettingCellModel(
                title: "Onchain Balance Satoshi".localized,
                subtitle: nil,
                value: onchainBalanceSatoshiText,
                hiddenIcon: true)
        case .blockHeight:
            return LTSettingCellModel(
                title: "Block Height".localized,
                subtitle: nil,
                value: "\(blockHeight ?? 0)",
                hiddenIcon: true)
        }
    }

    var onchainBalanceSatoshi: UInt64? {
        return lightningSession.nodeState?.onchainBalanceSatoshi
    }
    var onchainBalanceSatoshiText: String {
        return asStr(satoshi: onchainBalanceSatoshi ?? 0)
    }

    var hideBtnSendAll: Bool {
        return (lightningSession.nodeState?.channelsBalanceSatoshi ?? 0 == 0)
    }

    var id: String {
        return lightningSession.nodeState?.id ?? ""
    }

    var channelsBalance: UInt64? {
        return lightningSession.nodeState?.channelsBalanceSatoshi
    }

    var channelsBalanceText: String {
        return asStr(satoshi: channelsBalance ?? 0)
    }

    var inboundLiquidity: String {
        return asStr(satoshi: lightningSession.nodeState?.inboundLiquiditySatoshi)
    }

    var maxPayble: String {
        return asStr(satoshi: lightningSession.nodeState?.maxPaybleSatoshi)
    }

    var maxSinglePaymentAmount: String {
        return asStr(satoshi: lightningSession.nodeState?.maxSinglePaymentAmountSatoshi)
    }

    var maxReceivable: String {
        return asStr(satoshi: lightningSession.nodeState?.maxReceivableSatoshi)
    }

    var connectedPeers: String {
        return lightningSession.nodeState?.connectedPeers.joined(separator: ", ") ?? ""
    }
    var blockHeight: UInt32? {
        return lightningSession.nodeState?.blockHeight
    }

    init(lightningSession: LightningSessionManager) {
        self.lightningSession = lightningSession
    }

    func asStr(satoshi: UInt64?) -> String {
        let satoshi = satoshi ?? 0

        if let balance = Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId) {
            let (amount, denom) = balance.toDenom()
            return "\(amount) \(denom)"
        }
        return ""
    }

    func disableLightning() async {
        try? await WalletManager.current?.unregisterLightning()
        await WalletManager.current?.removeLightning()
    }

    func ltRecoverFundsViewModelSendAll() -> LTRecoverFundsViewModel? {
        guard let subaccount = WalletManager.current?.lightningSubaccount else {
            return nil
        }
        return LTRecoverFundsViewModel(
            wallet: subaccount,
            amount: nil,
            type: .sendAll)
    }
    func ltRecoverFundsViewModelSweep() -> LTRecoverFundsViewModel? {
        guard let subaccount = WalletManager.current?.lightningSubaccount else {
            return nil
        }
        return LTRecoverFundsViewModel(
            wallet: subaccount,
            amount: nil,
            type: .sweep)
    }
}
