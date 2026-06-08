import Foundation
import gdk
import core
import lightning
import GreenlightSDK

enum LTSettingsDialogCellType: CaseIterable {
    case id
    case totalBalance
    case channelsBalance
    case inboundLiquidity
    case maxPayble
    case onchainBalanceSatoshi
    case blockHeight
}

class LTSettingsDialogViewModel {
    var mainAccount: Account
    var wallet: WalletDataModel
    var lightningSession: LightningSessionManager
    var nodeInfo: NodeState?

    init(mainAccount: Account,
         wallet: WalletDataModel,
         lightningSession: LightningSessionManager) {
        self.mainAccount = mainAccount
        self.wallet = wallet
        self.lightningSession = lightningSession
        self.nodeInfo = lightningSession.nodeState()
    }

    var cellTypes: [LTSettingsDialogCellType] {
        return LTSettingsDialogCellType.allCases
    }
    
    var totalBalanceSatoshi: UInt64? {
        return nodeInfo?.totalBalanceMsat.satoshi
    }

    var totalBalanceSatoshiText: String {
        return asStr(satoshi: nodeInfo?.totalBalanceMsat.satoshi ?? 0)
    }

    var onchainBalanceSatoshi: UInt64? {
        return nodeInfo?.onchainBalanceMsat.satoshi
    }

    var onchainBalanceSatoshiText: String {
        return asStr(satoshi: onchainBalanceSatoshi ?? 0)
    }

    var hideBtnSendAll: Bool {
        return nodeInfo?.channelsBalanceMsat.satoshi ?? 0 == 0
    }

    var id: String {
        return nodeInfo?.id ?? ""
    }

    var channelsBalance: UInt64? {
        return nodeInfo?.channelsBalanceMsat.satoshi
    }

    var channelsBalanceText: String {
        return asStr(satoshi: channelsBalance ?? 0)
    }
    
    var inboundLiquidity: UInt64? {
        return nodeInfo?.totalInboundLiquidityMsat.satoshi
    }

    var inboundLiquidityText: String {
        return asStr(satoshi: nodeInfo?.totalInboundLiquidityMsat.satoshi)
    }
    
    var maxPayble: UInt64? {
        return nodeInfo?.maxPayableMsat.satoshi
    }

    var maxPaybleText: String {
        return asStr(satoshi: nodeInfo?.maxPayableMsat.satoshi)
    }

    var maxSinglePaymentAmount: String {
        return asStr(satoshi: nodeInfo?.maxPayableMsat.satoshi)
    }

    var maxReceivable: String {
        return asStr(satoshi: nodeInfo?.maxReceivableSinglePaymentMsat.satoshi)
    }

    var connectedPeers: String {
        return nodeInfo?.connectedChannelPeers.joined(separator: ", ") ?? ""
    }
    
    var blockHeight: UInt32? {
        return nodeInfo?.blockHeight
    }
    
    func diagnosticData() async -> String? {
        "" //await lightningSession.diagnosticData()
    }
    
    func cellModelByType(_ cellType: LTSettingsDialogCellType) ->LTSettingDialogCellModel {
        switch cellType {
        case .id:
            return LTSettingDialogCellModel(
                title: "ID",
                subtitle: nil,
                value: "\(id.prefix(8))...\(id.suffix(8))",
                hiddenIcon: false)
        case .totalBalance:
            return LTSettingDialogCellModel(
                title: "id_account_balance".localized,
                subtitle: nil,
                value: totalBalanceSatoshiText,
                hiddenIcon: false)
        case .channelsBalance:
            return LTSettingDialogCellModel(
                title: "Channel Balance".localized,
                subtitle: nil,
                value: channelsBalanceText,
                hiddenIcon: false)
        case .inboundLiquidity:
            return LTSettingDialogCellModel(
                title: "id_inbound_liquidity".localized,
                subtitle: nil,
                value: inboundLiquidityText,
                hiddenIcon: false)
        case .maxPayble:
            return LTSettingDialogCellModel(
                title: "id_max_payable_amount".localized,
                subtitle: nil,
                value: maxPaybleText,
                hiddenIcon: false)
        case .onchainBalanceSatoshi:
            return LTSettingDialogCellModel(
                title: "Onchain Balance".localized,
                subtitle: nil,
                value: onchainBalanceSatoshiText,
                hiddenIcon: false)
        case .blockHeight:
            return LTSettingDialogCellModel(
                title: "id_block_height".localized,
                subtitle: nil,
                value: "\(blockHeight ?? 0)",
                hiddenIcon: false)
        }
    }
    
    func copyValueByType(for cellType: LTSettingsDialogCellType) -> String {
        switch cellType {
        case .id:
            return id
        case .totalBalance:
            return asNumStr(satoshi: totalBalanceSatoshi)
        case .channelsBalance:
            return asNumStr(satoshi: channelsBalance)
        case .inboundLiquidity:
            return asNumStr(satoshi: inboundLiquidity)
        case .maxPayble:
            return asNumStr(satoshi: maxPayble)
        case .onchainBalanceSatoshi:
            return asNumStr(satoshi: onchainBalanceSatoshi)
        case .blockHeight:
            return "\(blockHeight ?? 0)"
        }
    }
    
    func updateNodeInfo() async {
        nodeInfo = try? await lightningSession.updateNodeInfoState()
    }

    func asStr(satoshi: UInt64?) -> String {
        let satoshi = satoshi ?? 0

        if let balance = Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId) {
            let (amount, denom) = balance.toDenom()
            return "\(amount) \(denom)"
        }
        return ""
    }

    func asNumStr(satoshi: UInt64?) -> String {
        let satoshi = satoshi ?? 0

        if let balance = Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId) {
            let (amount, _) = balance.toDenom()
            
            let decimalSeparator = Locale.current.decimalSeparator ?? "."
            let groupingSeparator = Locale.current.groupingSeparator ?? ","
            
            var cleanAmount = amount
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{00a0}", with: "")
                .replacingOccurrences(of: "\u{202F}", with: "")
            
            if groupingSeparator != decimalSeparator {
                cleanAmount = cleanAmount.replacingOccurrences(of: groupingSeparator, with: "")
            }
            
            if decimalSeparator != "," {
                cleanAmount = cleanAmount.replacingOccurrences(of: ",", with: "")
            }
            
            return cleanAmount
        }
        return ""
    }

    func disableLightning() async {
        await lightningSession.disconnect()
        mainAccount.removeAuthentication(.AuthKeyLightning)
        // Update subaccounts and UI
        await wallet.triggerRefresh(
            features: [.subaccounts]
        )
        await wallet
            .triggerRefresh(
                features: [.balance, .txs(reset: true)]
            )
    }

    func newAddress() async -> String? {
        return try? await lightningSession.getReceiveAddress(subaccount: 0).address
    }
}
