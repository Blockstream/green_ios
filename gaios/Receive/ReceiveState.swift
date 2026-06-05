import Foundation
import UIKit
import core
import gdk
import LiquidWalletKit
import greenaddress
import lightning

enum AmountFieldScope {
    case ltReceive
    case reverseSwap
}

enum AmountFieldState: Int {
    case valid
    case tooLow
    case disabled
    case invalidReverseSwap
    case lnBelowMin
    case lnAboveMax
    case lnRecommend
    case lnShowFunding
}

struct ReceiveState {
    var subaccount: WalletItem
    var type: ReceiveType
    var anyOrAsset: AnyOrAsset
    var satoshi: Int64?
    var selectedSegment: Int = 0
    var reverseSwapInfo: BoltzReverseSwapInfoLBTC?
    var inputDenomination: gdk.DenominationType
    // liquid / bitcoin address
    var address: gdk.Address?
    // lwk lightning invoice response
    var lwkInvoice: InvoiceResponse?
    // greenlight lightning invoice response
    var lightningReceivePayment: LightningReceivePayment?
    var isFiat: Bool = false
    var bolt11: String?
    var isLightning: Bool {
        subaccount.gdkNetwork.lightning
    }
    var description: String?
    var showVerify: Bool {
        AccountsRepository.shared.current?.isJade ?? false && !subaccount.isLightning && type == .address
    }
    var assetInfo: AssetInfo? {
        if case .asset(let assetId) = anyOrAsset {
            return WalletManager.current?.info(for: assetId)
        }
        return nil
    }
    var assetIcon: UIImage? {
        switch anyOrAsset {
        case .anyLiquid:
            return UIImage(named: "default_asset_liquid_icon")!
        case .anyAmp:
            return UIImage(named: "default_asset_amp_icon")!
        case .asset(let assetId):
            return WalletManager.current?.image(for: assetId)
        }
    }
    var assetName: String {
        switch anyOrAsset {
        case .anyLiquid:
            return "id_receive_any_liquid_asset".localized
        case .anyAmp:
            return "id_receive_any_amp_asset".localized
        case .asset(let assetId):
            return assetInfo?.name ?? assetId
        }
    }
    func isLBTC() -> Bool {
        return assetInfo?.assetId == AssetInfo.lbtcId
    }
    var showAmountView: Bool {
        if anyOrAsset.assetId == AssetInfo.lbtcId {
            switch type {
            case .lwkSwap:
                return true
            default:
                return false
            }
        }
        switch type {
        case .bolt11:
            return true
        default:
            return false
        }
    }
    var showAddressView: Bool {
        if anyOrAsset.assetId == AssetInfo.lbtcId {
            switch type {
            case .lwkSwap:
                return false
            default:
                return true
            }
        }
        switch type {
        case .address:
            return true
        default:
            return false
        }
    }
    let minAmountOpening: UInt64 = 25000
    var gdkNetwork: gdk.GdkNetwork? {
        subaccount.session?.gdkNetwork
    }
    var scope: AmountFieldScope {
        type == .lwkSwap ? .reverseSwap : .ltReceive
    }
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
    func message(_ state: AmountFieldState) -> String? {
        if state == .invalidReverseSwap {
            if let minReverseSwapText, let maxReverseSwapText {
                return "Type an amount between \(minReverseSwapText) and \(maxReverseSwapText)."
            }
            return "Invalid amount".localized
        } else if state == .tooLow {
            let amount = Int64(minAmountOpening)
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
    var lnRecommendedSatoshis: UInt64 {
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
    func lnMessage(_ state: AmountFieldState) -> String {
        switch state {
        case .lnBelowMin:
            return String(format: "Minimum is %@".localized, lnLimitsStr(satoshi: lnMinSatoshis, showFiat: true))
        case .lnAboveMax:
            return String(format: "Maximum is %@".localized, lnLimitsStr(satoshi: lnMaxSatoshis, showFiat: true))
        case .lnRecommend:
            return String(format: "Recommended amount is at least %@ to avoid high funding fees. Learn why.".localized,
                          lnLimitsStr(satoshi: lnRecommendedSatoshis, showFiat: false))
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
    func getSatoshi(_ value: String) -> Int64? {
        if isFiat {
            let balance = Balance.fromFiat(value, assetId: AssetInfo.btcId)
            return balance?.satoshi
        } else {
            let balance = Balance.from(value, assetId: AssetInfo.btcId, denomination: inputDenomination)
            return balance?.satoshi
        }
    }
    var isBip21: Bool {
        return text?.hasPrefix("bitcoin:") ?? false ||
            text?.hasPrefix("lightning:") ?? false ||
            text?.hasPrefix("liquidnetwork:") ?? false
    }

    var text: String? {
        switch type {
        case .bolt11:
            return bolt11
        case .lwkSwap:
            return bolt11
        case .address:
            if let address = address?.address {
                if !AssetInfo.baseIds.contains(where: { $0 == anyOrAsset.assetId }) {
                    return addressToUri(address: address, satoshi: satoshi ?? 0, assetId: anyOrAsset.assetId)
                } else if satoshi != nil {
                    return addressToUri(address: address, satoshi: satoshi ?? 0, assetId: anyOrAsset.assetId)
                } else {
                    return address
                }
            }
            return nil
        }
    }
    func addressToUri(address: String, satoshi: Int64?, assetId: String?) -> String {
        var params = [String]()
        if let satoshi = satoshi, satoshi > 0 {
            let amount = String(format: "%.8f", toBTC(satoshi))
            params += ["amount=\(amount)"]
        }
        if let assetId = assetId {
            if subaccount.gdkNetwork.liquid && satoshi ?? 0 > 0 {
                params += ["assetid=\(assetId)"]
            } else if !AssetInfo.baseIds.contains(assetId) {
                params += ["assetid=\(assetId)"]
            }
        }
        let bip21Prefix = subaccount.gdkNetwork.bip21Prefix ?? ""
        let queryString = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        return "\(bip21Prefix):\(address)\(queryString)"
    }
    func toBTC(_ satoshi: Int64) -> Double {
        return Double(satoshi) / 100000000
    }
}
