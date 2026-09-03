import Foundation

import core

class DenominationExchangeViewModel {

    let mainWallet: Wallet
    let manager: WalletManager

    var backend: GdkNetworkBackend? {
        manager.prominentNetworkBackend
    }
    var settings: Settings? { backend?.settings }
    var networkId: NetworkId? { backend?.networkId }

    internal init(mainWallet: Wallet, manager: WalletManager) {
        self.mainWallet = mainWallet
        self.manager = manager
    }
    var editingDenomination: DenominationType?
    var editingExchange: CurrencyItem?

    func currentSymbol() -> DenominationType {
        guard let settings = settings else { return .BTC }
        return editingDenomination != nil ? editingDenomination! : settings.denomination
    }

    func currentSymbolStr() -> String {
        let denominations = DenominationType.denominationsBTC
        if let denom = denominations.filter({ $0.key == currentSymbol() }).first?.value {
            return denom
        }
        return denominations[.BTC] ?? "btc"
    }

    func currentExchange() -> String {
        if let editingExchange = editingExchange {
            return "\(editingExchange.currency) \("id_from".localized.lowercased()) \(editingExchange.exchange.uppercased())"
        }
        guard let settings = settings else { return "" }
        return "\(settings.pricing["currency"]!) \("id_from".localized.lowercased()) \(settings.pricing["exchange"]!.uppercased())"
    }

    func pricing() -> [String: String]? {
        if let editingExchange = editingExchange {
            var pricing: [String: String] = [:]
            pricing["currency"] = editingExchange.currency
            pricing["exchange"] = editingExchange.exchange
            return pricing
        }
        return nil
    }

    func dialogDenominationViewModel() -> DialogDenominationViewModel? {
        let list: [DenominationType] = [ .BTC, .MilliBTC, .MicroBTC, .Bits, .Sats]
        guard let backend = backend, let settings = backend.settings else { return nil }
        return DialogDenominationViewModel(denomination: settings.denomination,
                                           denominations: list,
                                           network: backend.networkId)
    }

    func updateSettings(_ settings: Settings) async throws {
        for networkId in manager.activeNetworkIds {
            let backend = try? manager.gdkNetworkBackend(networkId)
            _ = try? await backend?.changeSettings(settings)
        }
    }
}
