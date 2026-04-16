import Foundation
import UIKit
import gdk

public protocol ConverterProvider {
    func convertBitcoinAmount(params: Balance) throws -> Balance?
    func convertLiquidAmount(params: Balance) throws -> Balance?
}

public class ConverterManager {

    private let provider: ConverterProvider
    private let testnet: Bool
    public static let enUSLocale = Locale(identifier: "en_US")

    private let fiatFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        formatter.currencySymbol = ""
        formatter.usesGroupingSeparator = true
        return formatter
    }()
    private let fiatFormatterNoSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        formatter.currencySymbol = ""
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private let btcFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.locale = .current
        formatter.usesGroupingSeparator = true
        return formatter
    }()
    private let btcFormatterNoSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.locale = .current
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private func assetFormatter(precision: Int, separator: Bool) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = precision
        formatter.locale = .current
        formatter.usesGroupingSeparator = separator
        return formatter
    }

    public init(provider: ConverterProvider, testnet: Bool) {
        self.provider = provider
        self.testnet = testnet
    }

    public func convertAmount(balance: Balance) throws -> Balance? {
        if AssetInfo.baseIds.contains(balance.assetId ?? AssetInfo.btcId) {
            return try provider.convertBitcoinAmount(params: balance)
        } else {
            return try provider.convertLiquidAmount(params: balance)
        }
    }

    func getBtcFromBalance(_ b: Balance, _ denomination: DenominationType) -> String? {
        switch denomination {
        case .BTC:
            return b.btc
        case .MilliBTC:
            return b.mbtc
        case .MicroBTC:
            return b.ubtc
        case .Bits:
            return b.bits
        case .Sats:
            return b.sats
        }
    }

    // Result as "value currency"
    public func formatFiat(_ b: Balance, withCurrency: Bool = true, withGroupSeparator: Bool = true) -> String? {
        guard let fiat = b.fiat,
              let val = Decimal(string: fiat, locale: Self.enUSLocale) else {
            return nil
        }
        if withCurrency, let fiatCurrency = b.fiatCurrency {
            return formatFiat(value: val, currency: fiatCurrency, withGroupSeparator: withGroupSeparator)
        } else {
            return formatFiat(value: val, currency: nil, withGroupSeparator: withGroupSeparator)
        }
    }
    public func formatFiat(value: Decimal, currency: String? = nil, withGroupSeparator: Bool = true) -> String? {

        let formatter = withGroupSeparator ? fiatFormatter : fiatFormatterNoSeparator
        guard let numberStr = formatter.string(from: value as NSDecimalNumber) else {
            return nil
        }
        if let currency {
            return "\(numberStr) \(currency)"
        } else {
            return numberStr
        }
    }
    public func formatBTC(_ b: Balance, denomination: DenominationType, withDenomination: Bool = true, withGroupSeparator: Bool = true) -> String? {
        guard let value = getBtcFromBalance(b, denomination),
                let val = Decimal(string: value, locale: Self.enUSLocale) else {
            return nil
        }
        let formatter = withGroupSeparator ? btcFormatter : btcFormatterNoSeparator
        guard let number = formatter.string(from: val as NSDecimalNumber) else {
            return nil
        }
        if withDenomination {
            var network = testnet ? NetworkSecurityCase.testnetSS : NetworkSecurityCase.bitcoinSS
            if b.assetId == AssetInfo.lbtcId || b.assetId == AssetInfo.ltestId {
                network = testnet ? NetworkSecurityCase.testnetLiquidSS : NetworkSecurityCase.liquidSS
            }
            let denominations = DenominationType.denominations(for: network.gdkNetwork)
            let denominationText = denominations[denomination]
            return "\(number) \(denominationText ?? "")"
        } else {
            return number
        }
    }
    public func formatAsset(_ b: Balance, withTicker: Bool = true, withGroupSeparator: Bool = true) -> String? {
        guard let value = b.assetValue,
                let val = Decimal(string: value, locale: Self.enUSLocale) else {
            return nil
        }
        let formatter = assetFormatter(precision: Int(b.assetInfo?.precision ?? 8), separator: withGroupSeparator)
        guard let number = formatter.string(from: val as NSDecimalNumber) else {
            return nil
        }
        if withTicker, let ticker = b.assetInfo?.ticker {
            return "\(number) \(ticker)"
        } else {
            return number
        }
    }
}
