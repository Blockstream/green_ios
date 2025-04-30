import Foundation
import gdk
import core

extension Balance {

    static var session: SessionManager? { WalletManager.current?.prominentSession }

    static func isBtc(_ assetId: String?) -> Bool {
        if assetId == nil {
            return true
        }
        return AssetInfo.baseIds.contains(assetId ?? "")
    }
    static func getAsset(_ assetId: String) -> AssetInfo? {
        return WalletManager.current?.info(for: assetId)
    }

    static func from(details: [String: Any]) -> Balance? {
        if session?.paused ?? false {
            // avoid blocking gdk mutex
            return nil
        }
        // convert
        guard var res = try? session?.convertAmount(input: details) else {
            return nil
        }
        // normalize outputs
        res["asset_info"] = details["asset_info"]
        res["asset_id"] = details["asset_id"]
        if res.keys.contains(AssetInfo.lightningId) {
            res[AssetInfo.lightningId] = details["btc"]
        }
        // serialize balance
        var balance = Balance.from(res) as? Balance
        if let assetId = balance?.assetInfo?.assetId,
            let value = res[assetId] as? String {
            balance?.asset = [assetId: value]
        }
        return balance
    }

    static func fromFiat(_ fiat: String) -> Balance? {
        let fiat = fiat.unlocaleFormattedString()
        let details: [String: Any] = ["fiat": fiat]
        return Balance.from(details: details)
    }

    static func from(_ value: String, assetId: String, denomination: DenominationType? = nil) -> Balance? {
        if AssetInfo.baseIds.contains(assetId) {
            return fromDenomination(value, assetId: assetId, denomination: denomination)
        }
        return fromValue(value, assetId: assetId)
    }

    static func fromDenomination(_ value: String, assetId: String, denomination: DenominationType? = nil) -> Balance? {
        let value = value.unlocaleFormattedString()
        let denomination = denomination ?? session?.settings?.denomination
        let details: [String: Any] = [denomination?.rawValue ?? Balance.session?.gdkNetwork.getFeeAsset() ?? "btc": value, "asset_id": assetId]
        return Balance.from(details: details)
    }

    static func fromValue(_ value: String, assetId: String) -> Balance? {
        let value = value.unlocaleFormattedString()
        var details: [String: Any] = [assetId: value,
                                      "asset_id": assetId]
        if let asset = getAsset(assetId), !isBtc(assetId) {
            details["asset_info"] = asset.encode()
        }
        return Balance.from(details: details)
    }

    static func fromSatoshi(_ satoshi: Any, assetId: String) -> Balance? {
        var details: [String: Any] = ["satoshi": satoshi]
        if let asset = getAsset(assetId), assetId != "btc" {
            details["asset_id"] = assetId
            details["asset_info"] = asset.encode()
        }
        return Balance.from(details: details)
    }

    static func fromSatoshi(_ satoshi: UInt64, assetId: String) -> Balance? {
        return Balance.fromSatoshi(Int64(satoshi), assetId: assetId)
    }

    func toFiat() -> (String, String) {
        let mainnet = AccountsRepository.shared.current?.gdkNetwork.mainnet
        if let asset = assetInfo, !AssetInfo.baseIds.contains(asset.assetId) {
            return ("", "")
        } else {
            return (fiat?.localeFormattedString(2) ?? "n/a", mainnet ?? true ? fiatCurrency : "FIAT")
        }
    }

    func toDenom(_ denomination: DenominationType? = nil) -> (String, String) {
        let denomination = denomination ?? Balance.session?.settings?.denomination ?? .BTC
        let res = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self), options: .allowFragments) as? [String: Any]
        let value = res![denomination.rawValue] as? String
        let network: NetworkSecurityCase = {
            switch assetId {
            case AssetInfo.lbtcId: return .liquidSS
            case AssetInfo.ltestId: return .testnetLiquidSS
            case AssetInfo.lightningId: return .lightning
            default: return Balance.session?.gdkNetwork.mainnet ?? true ? .bitcoinSS : .testnetSS
            }
        }()
        return (value?.localeFormattedString(Int(denomination.digits)) ?? "n/a", denomination.string(for: network.gdkNetwork))
    }

    func toBTC() -> (String, String) {
        let denomination: DenominationType = .BTC
        let res = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self), options: .allowFragments) as? [String: Any]
        let value = res![denomination.rawValue] as? String
        return (value?.localeFormattedString(Int(denomination.digits)) ?? "n/a", denomination.string(for: Balance.session?.gdkNetwork ?? GdkNetworks.shared.bitcoinSS))
    }

    func toAssetValue() -> (String, String) {
        return (asset?.first?.value.localeFormattedString(Int(assetInfo?.precision ?? 8)) ?? "n/a", assetInfo?.ticker ?? "n/a")
    }

    func toValue(_ denomination: DenominationType? = nil) -> (String, String) {
        if !Balance.isBtc(assetId) {
            return toAssetValue()
        } else {
            return toDenom(denomination)
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

extension Balance {

    func toInputDenom(inputDenomination: gdk.DenominationType?) -> (String, String) {
        if let inputDenomination = inputDenomination {
            let res = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self), options: .allowFragments) as? [String: Any]
            let value = res![inputDenomination.rawValue] as? String
            let network: NetworkSecurityCase = {
                switch assetId {
                case AssetInfo.lbtcId: return .liquidSS
                case AssetInfo.ltestId: return .testnetLiquidSS
                case AssetInfo.lightningId: return .lightning
                default: return Balance.session?.gdkNetwork.mainnet ?? true ? .bitcoinSS : .testnetSS
                }
            }()
            return (value?.localeFormattedString(Int(inputDenomination.digits)) ?? "n/a", inputDenomination.string(for: network.gdkNetwork))
        } else {
            return toDenom()
        }
    }

    func toInputDenominationValue(_ denomination: gdk.DenominationType?) -> (String, String) {
        if let denomination = denomination {
            if !Balance.isBtc(assetId) {
                return toAssetValue()
            } else {
                return toInputDenom(inputDenomination: denomination)
            }
        } else {
            return toValue()
        }
    }
}
