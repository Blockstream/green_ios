import Foundation
import UIKit
import gdk
import lightning
import core

enum AmountCellScope {
    case ltReceive
    case reverseSwap
}
struct AmountCellModel {
    var satoshi: Int64?
    var openChannelFee: UInt64?
    var maxLimit: UInt64?
    var isFiat: Bool
    var inputDenomination: gdk.DenominationType
    var gdkNetwork: gdk.GdkNetwork?
    var scope: AmountCellScope
    var reverseSwapInfo: BoltzReverseSwapInfoLBTC?

    var network: NetworkSecurityCase?
    var amount: String? { isFiat ? fiat : btc }
    var subamountText: String? { isFiat ? "≈ \(btc ?? "") \(denominationHint ?? "")" : "≈ \(fiat ?? "") \(currency ?? "")" }
    var ticker: String? {
        if isFiat {
            return currency == nil ? defaultCurrency : currency
        } else {
            return denomText
        }
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
        } else if state == .tooLow {
            let amount = Int64(openChannelFee ?? 0)
            return String(format: "id_a_set_up_funding_fee_of_s_s".localized, toBtcText(amount) ?? "", toFiatText(amount) ?? "")
        }
        return nil
    }
    var showMessage: Bool {
        return network == .lightning && satoshi != nil
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
        if let satoshi = satoshi, let openChannelFee = openChannelFee, let balance = Balance.fromSatoshi(satoshi - Int64(openChannelFee), assetId: "btc") {
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
            return Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId)?.toDenom(inputDenomination, locale: false).0
        }
        return nil
    }
    var fiat: String? {
        if let satoshi = satoshi {
            return Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId)?.toFiat(locale: false).0
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
            /*if satoshi >= nodeState.maxReceivableSatoshi {
                return .tooHigh
            } else if satoshi <= nodeState.inboundLiquiditySatoshi || satoshi >= openChannelFee ?? 0 {
                if nodeState.inboundLiquiditySatoshi == 0 || satoshi > nodeState.inboundLiquiditySatoshi {
                    return .aboveInboundLiquidity
                } else {
                    return .valid
                }
            } else
            */
            if satoshi <= openChannelFee ?? 0 {
                return .tooLow
            } else {
                return .valid
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
        return Balance.fromSatoshi(Int64(0), assetId: AssetInfo.btcId)?.toFiat().1
    }()
    var defaultDenomination: String? = {
        return Balance.fromSatoshi(Int64(0), assetId: AssetInfo.btcId)?.toDenom().1
    }()

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
