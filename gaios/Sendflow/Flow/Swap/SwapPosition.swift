import Foundation
import UIKit
import core
import LiquidWalletKit

enum SwapPositionEnum: Sendable {
    case from
    case to

    var title: String {
        switch self {
        case .from: "Swap from"
        case .to: "Swap to"
        }
    }
}

struct SwapPositionState: Sendable {
    var from: SwapPosition
    var to: SwapPosition
    var priority: TransactionPriority
    var error: Error?
    var isFiat: Bool = false
    var denomination: DenominationType
    var feeRate: UInt64?
    var networkFee: UInt64?
    var boltzFee: UInt64?
}
enum SwapChainName: String {
    case mainnet = "mainnet"
    case liquid = "liquid"
    case lightning = "lightning"
}

enum SwapNetwork: Hashable {
    case bitcoin
    case liquid
    case lightning
}

struct SwapDirection: Hashable {
    let from: SwapNetwork
    let to: SwapNetwork
}

struct SwapAvailability {
    let enabledDirections: Set<SwapDirection>

    // New swap creation is temporarily unavailable. Keep this list scoped by
    // direction so pairs can be restored independently during rollout.
    static let current = SwapAvailability(enabledDirections: [])

    func isCreationEnabled(_ direction: SwapDirection) -> Bool {
        enabledDirections.contains(direction)
    }

    static func isCreationEnabled(_ direction: SwapDirection) -> Bool {
        current.isCreationEnabled(direction)
    }

    static var hasEnabledCreationDirection: Bool {
        !current.enabledDirections.isEmpty
    }
}
enum SwapRoute: Sendable {
    case chain
    case btcToLn
    case lnToBtc
}

extension SwapAssetType {
    var swapNetwork: SwapNetwork {
        switch self {
        case .bitcoin:
            return .bitcoin
        case .liquid:
            return .liquid
        case .lightning:
            return .lightning
        }
    }
}
extension SwapPositionState {
    var route: SwapRoute {
        if from.type == .lightning {
            return .lnToBtc
        } else if to.type == .lightning {
            return .btcToLn
        } else {
            return .chain
        }
    }
    
    var currency: String? {
        Balance.fromSatoshi(Int64(0), assetId: AssetInfo.btcId)?.toFiat().1
    }
    var availableFrom: String? {
        guard let available = from.available,
              let text = formatAmount(available, assetId: from.assetId, asFiat: isFiat) else { return nil }
        return "Available: \(text)"
    }

    var availableTo: String? {
        guard let available = to.available,
              let text = formatAmount(available, assetId: to.assetId, asFiat: isFiat) else { return nil }
        return "Available: \(text)"
    }
    var amountFrom: String? {
        guard let satoshi = from.amount, satoshi > 0 else { return nil }
        if isFiat {
            return fiat(Int64(satoshi), assetId: from.assetId)
        } else {
            return btc(Int64(satoshi), assetId: from.assetId, denomination: denomination)
        }
    }
    var amountTo: String? {
        guard let satoshi = to.amount, satoshi > 0 else { return nil }
        if isFiat {
            return fiat(Int64(satoshi), assetId: to.assetId)
        } else {
            return btc(Int64(satoshi), assetId: to.assetId, denomination: denomination)
        }
    }
    var subamountFrom: String? {
        let satoshi = from.amount ?? 0
        guard let text = formatAmount(Int64(satoshi), assetId: from.assetId, asFiat: !isFiat) else {
            return nil
        }
        return "≈ \(text)"
    }
    var subamountTo: String? {
        let satoshi = to.amount ?? 0
        guard let text = formatAmount(Int64(satoshi), assetId: to.assetId, asFiat: !isFiat) else {
            return nil
        }
        return "≈ \(text)"
    }
    func fiat(_ satoshi: Int64, assetId: String) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toFiat(locale: false).0
    }
    func btc(_ satoshi: Int64, assetId: String, denomination: DenominationType) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toValue(denomination, locale: false).0
    }
    func fiatText(_ satoshi: Int64, assetId: String) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toFiatText()
    }
    func btcText(_ satoshi: Int64, assetId: String, denomination: DenominationType) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toText(denomination)
    }
    private func formatAmount(_ amount: Int64, assetId: String, asFiat: Bool) -> String? {
        return asFiat
            ? fiatText(amount, assetId: assetId)
            : btcText(amount, assetId: assetId, denomination: denomination)
    }
}

struct SwapPosition: Sendable {
    var side: SwapPositionEnum
    var type: SwapAssetType
    var account: Account?
    var assetId: String
    var amount: UInt64?
}
extension SwapPosition {

    init(position: SwapPositionEnum, type: SwapAssetType, account: Account?, assetId: String) {
        self.side = position
        self.type = type
        self.account = account
        self.assetId = assetId
    }

    var title: String {
        switch side {
        case .from: "From".localized
        case .to: "To".localized
        }
    }
    var swapAsset: SwapAsset {
        switch type {
        case .bitcoin: .onchain
        case .lightning: .lightning
        case .liquid: .liquid
        }
    }
    var accountName: String {
        return account?.localizedName ?? ""
    }
    var assetName: String {
        return type.title
    }
    var chain: String {
        switch type {
        case .bitcoin: SwapChainName.mainnet.rawValue
        case .lightning: SwapChainName.lightning.rawValue
        case .liquid: SwapChainName.liquid.rawValue
        }
    }
    func assetSymbol(_ inputDenomination: DenominationType) -> String {
        switch type {
        case .bitcoin, .lightning: DenominationType.denominationsBTC[inputDenomination] ?? ""
        case .liquid: DenominationType.denominationsLBTC[inputDenomination] ?? ""
        }
    }
    var assetIcon: UIImage {
        return type.icon ?? UIImage()
    }
    var available: Int64? {
        switch type {
        case .bitcoin, .liquid:
            if let account {
                return try? WalletManager.current?.accountBackend(account).assets[assetId]
            }
            return nil
        case .lightning:
            if let maxPayable = account?.lightningSession?.nodeState()?.maxSendableSatoshi {
                return Int64(maxPayable)
            }
            return nil
        }
    }
}

enum SwapFlowError: Error, Sendable, Equatable {
    case invalidAmount(msg: String, position: SwapPositionEnum?)
    case insufficientFunds
    case gdkError(String)
    case serviceUnavailable
    case unsupportedSwapPair
    case failedToBuildTransaction
    case invalidPaymentTarget

    func description() -> String {
        switch self {
        case .invalidAmount(let msg, _):
            return msg.localized
        case .insufficientFunds:
            return "id_insufficient_funds".localized
        case .gdkError(let msg):
            return msg.localized
        case .serviceUnavailable:
            return "Service temporary unavailable".localized
        case .unsupportedSwapPair:
            return "Swap pair is not supported yet".localized
        case .failedToBuildTransaction:
            return "Failed to build transaction".localized
        case .invalidPaymentTarget:
            return "id_invalid_address".localized
        }
    }

    var position: SwapPositionEnum? {
        if case .invalidAmount(_, let pos) = self { return pos }
        if case .insufficientFunds = self { return .from }
        return nil
    }
}
