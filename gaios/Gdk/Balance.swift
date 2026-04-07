import Foundation
import gdk
import core

struct BalanceRequest: Codable, Hashable {
    let satoshi: Int64
    let assetId: String?
}

extension Balance {

    static func isBtc(_ assetId: String?) -> Bool {
        if assetId == nil {
            return true
        }
        return AssetInfo.baseIds.contains(assetId ?? "")
    }
    static func getAsset(_ assetId: String) -> AssetInfo? {
        return WalletManager.current?.info(for: assetId)
    }

    static func convert(_ balance: Balance) -> Balance? {
        return try? WalletManager.current?.converter?.convertAmount(balance: balance)
    }

    static func fromFiat(_ fiat: String, assetId: String) -> Balance? {
        let fiat = fiat.unlocaleFormattedString()
        if AssetInfo.baseIds.contains(assetId) {
            let balance = Balance(fiat: fiat, assetId: assetId)
            return Balance.convert(balance)
        } else {
            let balance = Balance(fiat: fiat, assetInfo: getAsset(assetId), assetId: assetId)
            return Balance.convert(balance)
        }
    }

    static func from(_ value: String, assetId: String, denomination: DenominationType? = nil) -> Balance? {
        let value = value.unlocaleFormattedString()
        if AssetInfo.baseIds.contains(assetId) {
            let session = WalletManager.current?.prominentSession
            let denomination = denomination ?? session?.settings?.denomination ?? .BTC
            let balance = Balance.fromBtcDenomination(value: value, denomination: denomination, assetId: assetId)
            return Balance.convert(balance ?? Balance(assetId: assetId, assetValue: value))
        } else {
            let balance = Balance(assetInfo: getAsset(assetId), assetId: assetId, assetValue: value)
            return Balance.convert(balance)
        }
    }

    static private func fromBtcDenomination(value: String, denomination: DenominationType, assetId: String) -> Balance? {
        switch denomination {
        case .BTC:
            return Balance(btc: value, assetId: assetId)
        case .MilliBTC:
            return Balance(mbtc: value, assetId: assetId)
        case .MicroBTC:
            return Balance(ubtc: value, assetId: assetId)
        case .Bits:
            return Balance(bits: value, assetId: assetId)
        case .Sats:
            return Balance(sats: value, assetId: assetId)
        }
    }

    static func fromSatoshi(_ satoshi: UInt64, assetId: String) -> Balance? {
        return fromSatoshi(Int64(satoshi), assetId: assetId)
    }
    static func fromSatoshi(_ satoshi: Int64, assetId: String) -> Balance? {
        if assetId == AssetInfo.btcId {
            let balance = Balance(satoshi: satoshi)
            return Balance.convert(balance)
        } else if let asset = getAsset(assetId) {
            let balance = Balance(satoshi: satoshi, assetInfo: asset, assetId: assetId)
            return Balance.convert(balance)
        } else {
            let balance = Balance(satoshi: satoshi, assetId: assetId)
            return Balance.convert(balance)
        }
    }

    func toFiat(locale: Bool = true) -> (String, String) {
        guard let value = WalletManager.current?.converter?.formatFiat(self, withCurrency: false, withGroupSeparator: locale) else {
            if self.assetId == nil {
                return ("n/a", self.fiatCurrency ?? "")
            }
            return ("", "")
        }
        return (value, self.fiatCurrency ?? "")
    }

    func toDenom(_ denomination: DenominationType? = nil, locale: Bool = true) -> (String, String) {
        let session = WalletManager.current?.prominentSession
        let denomination = denomination ?? session?.settings?.denomination ?? .BTC
        let network: NetworkSecurityCase = {
            switch assetId {
            case AssetInfo.lbtcId: return .liquidSS
            case AssetInfo.ltestId: return .testnetLiquidSS
            case AssetInfo.lightningId: return .lightning
            default: return session?.gdkNetwork.mainnet ?? true ? .bitcoinSS : .testnetSS
            }
        }()
        let denominationText = denomination.string(for: network.gdkNetwork)
        let value = WalletManager.current?.converter?.formatBTC(self, denomination: denomination, withDenomination: false, withGroupSeparator: locale)
        return (value ?? "n/a", denominationText)
    }

    func toAssetValue(locale: Bool = true) -> (String, String) {
        let value = WalletManager.current?.converter?.formatAsset(self, withTicker: false, withGroupSeparator: locale)
        return (value ?? "", self.assetInfo?.ticker ?? "")
    }

    func toValue(_ denomination: DenominationType? = nil, locale: Bool = true) -> (String, String) {
        if !Balance.isBtc(assetId) {
            return toAssetValue(locale: locale)
        } else {
            return toDenom(denomination, locale: locale)
        }
    }

    func toText(_ denomination: DenominationType? = nil) -> String {
        let (amount, ticker) = toValue(denomination)
        return "\(amount) \(ticker)"
    }

    func toFiatText() -> String {
        let (amount, currency) = toFiat()
        return "\(amount) \(currency)"
    }
}
