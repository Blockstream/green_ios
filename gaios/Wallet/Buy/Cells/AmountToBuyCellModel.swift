import Foundation
import UIKit
import BreezSDK
import gdk
import lightning
import core

struct AmountToBuyCellModel {
    var satoshi: Int64?
    var isFiat: Bool
    var inputDenomination: gdk.DenominationType
    var network: NetworkSecurityCase?
    var swapInfo: SwapInfo?

    var amount: String? { isFiat ? fiat : btc }
    var subamountText: String? { isFiat ? "≈ \(btc ?? "") \(denomText ?? "")" : "≈ \(fiat ?? "") \(currency ?? "")" }

    var ticker: String? {
        if isFiat {
            return currency == nil ? defaultCurrency : currency
        } else {
            return denomText
        }
    }

    var denomText: String? {
        if let gdkNetwork = network?.gdkNetwork {
            return inputDenomination.string(for: gdkNetwork)
        } else {
            return defaultDenomination
        }
    }

    var denomUnderlineText: NSAttributedString {
        return NSAttributedString(string: ticker ?? "", attributes:
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

    var message: String? {
        return "Type an amount between \(minAllowedDepositText ?? "-") and \(maxAllowedDepositText ?? "-"). A minimum setup fee of \(channelOpeningFeesText ?? "-") will be applied to the received amount."
    }
    
    var state: AmountToBuyCellState {
        guard let satoshi = satoshi else { return .valid }
        if let maxAllowedDeposit = swapInfo?.maxAllowedDeposit,
            let minAllowedDeposit = swapInfo?.minAllowedDeposit,
           satoshi >= maxAllowedDeposit || satoshi < minAllowedDeposit {
            return .invalid
        }
        return .valid
    }

    var showMessage: Bool {
        return network == .lightning && swapInfo != nil && satoshi != nil
    }

    var hideSubamount: Bool {
        return satoshi == nil
    }

    var defaultCurrency: String? = {
        return Balance.fromSatoshi(0, assetId: AssetInfo.btcId)?.toFiat().1
    }()
    var defaultDenomination: String? = {
        return Balance.fromSatoshi(0, assetId: AssetInfo.btcId)?.toDenom().1
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
