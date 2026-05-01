import Foundation
import gdk
import core
import lightning
import GreenlightSDK

enum LTSettingsCellType: CaseIterable {
    case id
    case totalBalance
    case channelsBalance
    case inboundLiquidity
    case onchainBalanceSatoshi
    case blockHeight
}

class LTSettingsViewModel {

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

    func updateNodeInfo() async {
        nodeInfo = try? await lightningSession.updateNodeInfoState()
    }

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
        case .totalBalance:
            return LTSettingCellModel(
                title: "id_account_balance".localized,
                subtitle: nil,
                value: totalBalanceSatoshiText,
                hiddenIcon: true)
        case .channelsBalance:
            return LTSettingCellModel(
                title: "Channel Balance".localized,
                subtitle: nil,
                value: channelsBalanceText,
                hiddenIcon: true)
        case .inboundLiquidity:
            return LTSettingCellModel(
                title: "id_inbound_liquidity".localized,
                subtitle: nil,
                value: inboundLiquidity,
                hiddenIcon: true)
        case .onchainBalanceSatoshi:
            return LTSettingCellModel(
                title: "id_onchain_balance_satoshi".localized,
                subtitle: nil,
                value: onchainBalanceSatoshiText,
                hiddenIcon: true)
        case .blockHeight:
            return LTSettingCellModel(
                title: "id_block_height".localized,
                subtitle: nil,
                value: "\(blockHeight ?? 0)",
                hiddenIcon: true)
        }
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

    var inboundLiquidity: String {
        return asStr(satoshi: nodeInfo?.totalInboundLiquidityMsat.satoshi)
    }

    var maxPayble: String {
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

    func asStr(satoshi: UInt64?) -> String {
        let satoshi = satoshi ?? 0

        if let balance = Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId) {
            let (amount, denom) = balance.toDenom()
            return "\(amount) \(denom)"
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
    func ltRedeemViewModel() -> LTRedeemViewModel? {
        guard let subaccount = WalletManager.current?.lightningSubaccount else {
            return nil
        }
        return LTRedeemViewModel(
            wallet: subaccount,
            amount: subaccount.lightningSession?
                .nodeState()?.onchainBalanceMsat.satoshi ?? 0)
    }

    func newAddress() async -> String? {
        return try? await lightningSession.getReceiveAddress(subaccount: 0).address
    }
}
