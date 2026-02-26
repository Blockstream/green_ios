import Foundation
import UIKit
import core
import LiquidWalletKit
@preconcurrency import gdk

enum SwapPositionEnum: Sendable {
    case from
    case to
}

struct SwapPositionState: Sendable {
    var from: SwapPosition
    var to: SwapPosition
    var priority: TransactionPriority
    var error: Error?
    var isFiat: Bool = false
    var denomination: gdk.DenominationType
    var feeRate: UInt64?
    var networkFee: UInt64?
}
enum SwapChainName: String {
    case mainnet = "mainnet"
    case liquid = "liquid"
    case lightning = "lightning"
}
extension SwapPositionState {
    var currency: String? {
        Balance.fromSatoshi(0, assetId: AssetInfo.btcId)?.toFiat().1
    }
    var availableFrom: String? {
        guard let available = from.available else { return nil }
        if isFiat {
            return fiatText(available, assetId: from.assetId)
        } else {
            return btcText(available, assetId: from.assetId, denomination: denomination)
        }
    }
    var availableTo: String? {
        guard let available = to.available else { return nil }
        if isFiat {
            return fiatText(available, assetId: to.assetId)
        } else {
            return btcText(available, assetId: to.assetId, denomination: denomination)
        }
    }
    var amountFrom: String? {
        guard let satoshi = from.amount else { return nil }
        if isFiat {
            return fiat(Int64(satoshi), assetId: from.assetId)
        } else {
            return btc(Int64(satoshi), assetId: from.assetId, denomination: denomination)
        }
    }
    var amountTo: String? {
        guard let satoshi = to.amount else { return nil }
        if isFiat {
            return fiat(Int64(satoshi), assetId: to.assetId)
        } else {
            return btc(Int64(satoshi), assetId: to.assetId, denomination: denomination)
        }
    }
    var subamountFrom: String? {
        guard let satoshi = from.amount else { return nil }
        if !isFiat {
            return fiatText(Int64(satoshi), assetId: from.assetId)
        } else {
            return btcText(Int64(satoshi), assetId: from.assetId, denomination: denomination)
        }
    }
    var subamountTo: String? {
        guard let satoshi = to.amount else { return nil }
        if !isFiat {
            return fiatText(Int64(satoshi), assetId: to.assetId)
        } else {
            return btcText(Int64(satoshi), assetId: to.assetId, denomination: denomination)
        }
    }
    func fiat(_ satoshi: Int64, assetId: String) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toFiat().0
    }
    func btc(_ satoshi: Int64, assetId: String, denomination: DenominationType) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toValue(denomination).0
    }
    func fiatText(_ satoshi: Int64, assetId: String) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toFiatText()
    }
    func btcText(_ satoshi: Int64, assetId: String, denomination: DenominationType) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toText(denomination)
    }
}

struct SwapPosition: Sendable {
    var side: SwapPositionEnum
    var account: WalletItem?
    var assetId: String
    var amount: UInt64?
}
extension SwapPosition {
    var title: String {
        switch side {
        case .from:
            return "From".localized + ": "
        case .to:
            return "To".localized + ": "
        }
    }
    var swapAsset: SwapAsset {
        if assetId == AssetInfo.btcId {
            return .onchain
        } else {
            return .liquid
        }
    }
    var accountName: String {
        return account?.localizedName ?? ""
    }
    var assetName: String {
        if assetId == AssetInfo.btcId {
            return "Bitcoin"
        } else if assetId == AssetInfo.lbtcId {
            return "Liquid Bitcoin"
        } else {
            return "N/A"
        }
    }
    var chain: String {
        if assetId == AssetInfo.btcId {
            return SwapChainName.mainnet.rawValue
        } else if assetId == AssetInfo.lbtcId {
            return SwapChainName.liquid.rawValue
        } else {
            return ""
        }
    }
    func assetSymbol(_ inputDenomination: DenominationType) -> String {
        if assetId == AssetInfo.btcId {
            return DenominationType.denominationsBTC[inputDenomination] ?? ""
        } else if assetId == AssetInfo.lbtcId {
            return DenominationType.denominationsLBTC[inputDenomination] ?? ""
        } else {
            return "N/A"
        }
    }
    var assetIcon: UIImage {
        if assetId == AssetInfo.btcId {
            return UIImage(named: "ic_swap_bitcoin")!
        } else if assetId == AssetInfo.lbtcId {
            return UIImage(named: "ic_swap_liquid")!
        } else {
            return UIImage()
        }
    }
    var available: Int64? {
        return account?.satoshi?[assetId]
    }
    init(position: SwapPositionEnum, account: WalletItem?, assetId: String) {
        self.side = position
        self.account = account
        self.assetId = assetId
    }
}
