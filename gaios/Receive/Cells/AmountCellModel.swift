import Foundation
import UIKit
import gdk
import lightning
import core

enum AmountCellScope {
    case ltReceive
    case reverseSwap
}
enum AmountCellColorType {
    case error
    case warning
    case ready
}
struct AmountCellModel {
    var satoshi: Int64?
    var hasActiveChannel: Bool
    var minAmountOpening: UInt64?
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
            let amount = Int64(minAmountOpening ?? 0)
            return String(format: "id_amount_must_be_at_least_s".localized, toBtcText(amount) ?? "")
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
    var denomUnderlineText: NSAttributedString {
        return NSAttributedString(string: denomText ?? "", attributes:
                nil // [.underlineStyle: NSUnderlineStyle.single.rawValue]
        )
    }
    var lnReccomendedSatoshis: UInt64 {
        return AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigLnRecommendedSatoshis) as? UInt64 ?? 85_000
    }
    var lnMinSatoshis: UInt64 {
        return AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigLnMinSatoshis) as? UInt64 ?? 5_000
    }
    var lnMaxSatoshis: UInt64 {
        return AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigLnMaxSatoshis) as? UInt64 ?? 400_000
    }
    func lnLimitsStr(satoshi: UInt64?, showFiat: Bool) -> String {
        var str = "N/A"
        if let satoshi = satoshi, let balance = Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId) {
            let (value, denom) = balance.toDenom(inputDenomination)
            let (fiat, currency) = balance.toFiat()
            if showFiat {
                str = "\(value) \(denom) (≈ \(fiat) \(currency))"
            } else {
                str = "\(value) \(denom)"
            }
        }
        return str
    }
    func lnMessage(_ state: AmountCellState) -> String {
        switch state {
        case .lnBelowMin:
            return String(format: "Minimum is %@".localized, lnLimitsStr(satoshi: lnMinSatoshis, showFiat: true))
        case .lnAboveMax:
            return String(format: "Maximum is %@".localized, lnLimitsStr(satoshi: lnMaxSatoshis, showFiat: true))
        case .lnRecommend:
            return String(format: "Recommended amount is at least %@ to avoid high funding fees. Learn why.".localized,
                          lnLimitsStr(satoshi: lnReccomendedSatoshis, showFiat: false))
        case .lnShowFunding:
            return "Requires a funding fee. Learn why.".localized
        default:
            return ""
        }
    }
    func conversionText() -> String {
        if isFiat {
            if let satoshi = satoshi, let balance = Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId)?.toDenom(inputDenomination, locale: false) {
                return "\(balance.0) \(balance.1)"
            }
            return ""
        } else {
            if let satoshi = satoshi, let balance = Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId)?.toFiat(locale: false) {
                return "≈ \(balance.0) \(balance.1)"
            }
            return ""
        }
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
            if satoshi > lnMaxSatoshis {
                return .lnAboveMax
            }
            if hasActiveChannel && satoshi > maxLimit ?? 0 {
                // amount above inbound liquidity
                if satoshi < lnReccomendedSatoshis {
                    return .lnRecommend
                } else {
                    return .lnShowFunding
                }
            }
            if !hasActiveChannel {
                if satoshi < lnMinSatoshis {
                    return .lnBelowMin
                } else if satoshi >= lnMinSatoshis && satoshi < lnReccomendedSatoshis {
                    return .lnRecommend
                } else if satoshi >= lnReccomendedSatoshis && satoshi < lnMaxSatoshis {
                    return .lnShowFunding
                }
            }
            return .valid
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
