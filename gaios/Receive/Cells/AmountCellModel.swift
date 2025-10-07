import Foundation
import UIKit
import BreezSDK
import gdk
import lightning
import core

enum AmountCellScope {
    case ltReceive
    case reverseSwap
}
struct AmountCellModel {
    var satoshi: Int64?
    var openChannelFee: Int64?
    var maxLimit: UInt64?
    var isFiat: Bool
    var inputDenomination: gdk.DenominationType
    var gdkNetwork: gdk.GdkNetwork?
    var breezSdk: LightningBridge?
    var scope: AmountCellScope
    var reverseSwapInfo: BoltzReverseSwapInfoLBTC?

    var network: NetworkSecurityCase?
    var swapInfo: SwapInfo?
    var amount: String? { isFiat ? fiat : btc }
    var subamountText: String? { isFiat ? "≈ \(btc ?? "") \(denominationHint ?? "")" : "≈ \(fiat ?? "") \(currency ?? "")" }
    var ticker: String? {
        if isFiat {
            return currency == nil ? defaultCurrency : currency
        } else {
            return denomText
        }
    }
    var minAllowedDepositText: String? {
        guard let minAllowedDeposit = swapInfo?.minAllowedDeposit else { return nil }
        let balance = Balance.fromSatoshi(minAllowedDeposit, assetId: AssetInfo.btcId)
        return isFiat ? balance?.toFiatText() : balance?.toText(inputDenomination)
    }
    var maxAllowedDepositText: String? {
        guard let maxAllowedDeposit = swapInfo?.maxAllowedDeposit else { return nil }
        let balance = Balance.fromSatoshi(maxAllowedDeposit, assetId: AssetInfo.btcId)
        return isFiat ? balance?.toFiatText() : balance?.toText(inputDenomination)
    }
    var channelOpeningFeesText: String? {
        guard let channelOpeningFees = swapInfo?.channelOpeningFees?.minMsat.satoshi else { return nil }
        return "\(channelOpeningFees) sats"
    }
    var minReverseSwapText: String? {
        guard let min = reverseSwapInfo?.limits.minimal else { return nil }
        let balance = Balance.fromSatoshi(min, assetId: AssetInfo.btcId)
        return isFiat ? balance?.toFiatText() : balance?.toText(inputDenomination)
    }
    var maxReverseSwapText: String? {
        guard let max = reverseSwapInfo?.limits.maximal else { return nil }
        let balance = Balance.fromSatoshi(max, assetId: AssetInfo.btcId)
        return isFiat ? balance?.toFiatText() : balance?.toText(inputDenomination)
    }
    func message(_ state: AmountCellState) -> String? {
        if state == .invalidReverseSwap {
            if let minReverseSwapText, let maxReverseSwapText {
                return "Type an amount between \(minReverseSwapText) and \(maxReverseSwapText)."
            }
            return "Invalid amount"
        }
        if network == .lightning {
            if state == .invalidBuy {
                return "Type an amount between \(minAllowedDepositText ?? "-") and \(maxAllowedDepositText ?? "-"). A minimum setup fee of \(channelOpeningFeesText ?? "-") will be applied to the received amount."
            }
            let amount = Int64(swapInfo?.channelOpeningFees?.minMsat.satoshi ?? 0)
            return String(format: "id_a_set_up_funding_fee_of_s_s".localized, toBtcText(amount) ?? "", toFiatText(amount) ?? "")
        }
        return nil
    }
    var showMessage: Bool {
        return network == .lightning && swapInfo != nil && satoshi != nil
    }
    var hideSubamount: Bool {
        return satoshi == nil
    }
    var reverseSwapLimits: (Int64, Int64)? {
        if let info = reverseSwapInfo {
            let min = info.limits.minimal
            let max = info.limits.maximal
            return (min, max)
        }
        return nil
    }
    var amountText: String? { isFiat ? fiat : btc }
    var denomText: String? {
        if isFiat {
            return currency == nil ? defaultCurrency : currency
        } else {
            if let gdkNetwork = gdkNetwork {
                return inputDenomination.string(for: gdkNetwork)
            } else {
                return defaultDenomination
            }
        }
    }
    var denominationHint: String? {
        if let gdkNetwork = gdkNetwork {
            return inputDenomination.string(for: gdkNetwork)
        } else {
            return defaultDenomination
        }
    }
    var toReceiveAmountStr: String {
        if let satoshi = satoshi, let openChannelFee = openChannelFee, let balance = Balance.fromSatoshi(satoshi - openChannelFee, assetId: "btc") {
            let (value, denom) = balance.toDenom(inputDenomination)
            let (fiat, currency) = balance.toFiat()
            return "\(value) \(denom) ~(\(fiat) \(currency))"
        }
        return ""
    }
    var denomUnderlineText: NSAttributedString {
        return NSAttributedString(string: denomText ?? "", attributes:
                [.underlineStyle: NSUnderlineStyle.single.rawValue])
    }

    var btc: String? {
        if let satoshi = satoshi {
            return Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId)?.toDenom(inputDenomination).0
        }
        return nil
    }
    var fiat: String? {
        if let satoshi = satoshi {
            return Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId)?.toFiat().0
        }
        return nil
    }
    var currency: String? {
        if let satoshi = satoshi {
            return Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId)?.toFiat().1
        }
        return nil
    }

    var maxLimitAmount: String? {
        if let maxLimit = maxLimit {
            let balance = Balance.fromSatoshi(UInt64(maxLimit), assetId: AssetInfo.btcId)
            return isFiat ? balance?.toFiat().0 : balance?.toDenom(inputDenomination).0
        }
        return nil
    }

    var state: AmountCellState {
        guard let satoshi = satoshi else { return .disabled }
        switch scope {
        case .ltReceive:
            guard let _ = breezSdk?.lspInformation, let nodeState = breezSdk?.nodeInfo else {
                return .disconnected
            }
            if satoshi >= nodeState.maxReceivableSatoshi {
                return .tooHigh
            } else if satoshi <= nodeState.inboundLiquiditySatoshi || satoshi >= openChannelFee ?? 0 {
                if nodeState.inboundLiquiditySatoshi == 0 || satoshi > nodeState.inboundLiquiditySatoshi {
                    return .aboveInboundLiquidity
                } else {
                    return .valid
                }
            } else if satoshi <= openChannelFee ?? 0 {
                return .tooLow
            } else {
                return .disabled
            }
        case .reverseSwap:
            if satoshi < reverseSwapLimits?.0 ?? 0 || satoshi > reverseSwapLimits?.1 ?? 0 {
                return .invalidReverseSwap
            } else {
                return .valid
            }
        }
    }
    var defaultCurrency: String? = {
        return Balance.fromSatoshi(0, assetId: AssetInfo.btcId)?.toFiat().1
    }()
    var defaultDenomination: String? = {
        return Balance.fromSatoshi(0, assetId: AssetInfo.btcId)?.toDenom().1
    }()

    mutating func setOpenChannelFee(_ fee: Int64) {
        openChannelFee = fee
    }
    func buildOpenChannelFee(_ satoshi: Int64) async -> Int64? {
        let channelFee = try? breezSdk?.openChannelFee(satoshi: Long(satoshi))?.feeMsat?.satoshi
        if let channelFee = channelFee {
            return Int64(channelFee)
        }
        return nil
    }

    func toFiatText(_ amount: Int64?) -> String? {
        if let amount = amount {
            return Balance.fromSatoshi(amount, assetId: AssetInfo.btcId)?.toFiatText()
        }
        return nil
    }
    func toBtcText(_ amount: Int64?) -> String? {
        if let amount = amount {
            return Balance.fromSatoshi(amount, assetId: AssetInfo.btcId)?.toText(inputDenomination)
        }
        return nil
    }
}
