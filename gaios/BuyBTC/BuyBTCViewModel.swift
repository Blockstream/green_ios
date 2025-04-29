import Foundation
import UIKit
import gdk
import greenaddress
import hw
import BreezSDK
import lightning
import core

struct Tiers {
    let min: Double
    let mid: Double
    let max: Double

    var minStr: String {
        String(format: "%.0f", min)
    }
    var midStr: String {
        String(format: "%.0f", mid)
    }
    var maxStr: String {
        String(format: "%.0f", max)
    }
}
class BuyBTCViewModel {

    var asset: String
    var satoshi: Int64?
    var isFiat: Bool = true
    var account: WalletItem
    var accounts: [WalletItem]
    var inputDenomination: gdk.DenominationType = .Sats
    var state: AmountCellState = .invalidBuy
    var meld: Meld
    var wm: WalletManager { WalletManager.current! }
    var swapInfo: SwapInfo?
    var backupCardCellModel = [AlertCardCellModel]()
    var currency: String?
    var tiers: Tiers?
    var hideBalance = false
    var countryCode = (Locale.current.regionCode ?? "US").uppercased()
    var showNoQuotes: Bool {
        false
    }
    var showAccountSwitch: Bool {
        accounts.count > 1
    }
    var address: Address?
    var accountCellModels: [AccountCellModel] {
        var list = [AccountCellModel]()
        for subaccount in accounts {
            let assetId = "btc"
            if subaccount.hasAsset(assetId) {
                let satoshi = subaccount.satoshi?[assetId] ?? 0
                list += [AccountCellModel(account: subaccount, satoshi: satoshi, assetId: assetId)]
            }
        }
        return list
    }
    var dialogAccountsModel: DialogAccountsViewModel {
        return DialogAccountsViewModel(
            title: "Account Selector",
            hint: "Select the desired account you want to receive your bitcoin.".localized,
            isSelectable: true,
            assetInfo: WalletManager.current?.info(for: "btc"),
            accountCellModels: accountCellModels,
            hideBalance: hideBalance)
    }
    init(account: WalletItem,
         accounts: [WalletItem],
         currency: String?,
         hideBalance: Bool = false) {
        self.account = account
        self.asset = account.gdkNetwork.getFeeAsset()
        self.meld = Meld.init(isSandboxEnvironment: WalletManager.current?.testnet ?? false)
        self.inputDenomination = WalletManager.current?.prominentSession?.settings?.denomination ?? .Sats
        self.accounts = accounts
        self.hideBalance = hideBalance
        self.currency = currency
        self.loadTiers()
    }
    var isJade: Bool { wm.account.isJade }
    func quote(_ amountStr: String) async throws -> [MeldQuoteItem] {

        let params = MeldQuoteParams(
            destinationCurrencyCode: "BTC",
            countryCode: countryCode,
            sourceAmount: amountStr,
            sourceCurrencyCode: currency ?? "USD",
            paymentMethodType: "CARD")
        return try await meld.quote(params)
    }
    func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count > 1 {
            let first = components[0].prefix(1)
            let second = components[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else if !name.isEmpty {
            return String(name.prefix(2)).uppercased()
        }
        return "--"
    }
    func colorFromProviderName(_ name: String) -> UIColor {
        let hash = abs(name.hashValue)
        let hue = CGFloat(hash % 360) / 360.0
        return UIColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0)
    }
    func loadTiers() {
        if let config: Any = AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigBuyDefaultValues) {
            let json = try? JSONSerialization.data(withJSONObject: config, options: .fragmentsAllowed)
            let buyTiers = try? JSONDecoder().decode(BuyTiers.self, from: json ?? Data())
            if let currency = self.currency, let tiers = buyTiers {
                for (key, val) in tiers.buy_default_values where (key.uppercased() == currency.uppercased() && val.count == 3) {
                    self.tiers = Tiers(min: Double(val[0]), mid: Double(val[1]), max: Double(val[2]))
                }
            }
        }
    }
    func widget(quote: MeldQuoteItem, amountStr: String) async throws -> String {
        guard let addressStr = address?.address else {
           throw GaError.GenericError("Invalid address")
        }
        let sessionParams = MeldSessionParams(
            serviceProvider: quote.serviceProvider,
            countryCode: countryCode,
            destinationCurrencyCode: "BTC",
            lockFields: ["destinationCurrencyCode",
                         "walletAddress",
                         "sourceCurrencyCode"],
            paymentMethodType: "CARD",
            // redirectUrl: "",
            sourceAmount: amountStr,
            sourceCurrencyCode: currency ?? "USD",
            walletAddress: addressStr)
        let params = MeldWidgetParams(
            sessionData: sessionParams,
            sessionType: MeldTransactionType.BUY.rawValue)
        return try await meld.widget(params)
    }
    func verifyOnDeviceViewModel() -> VerifyOnDeviceViewModel? {
        guard let addressStr = address?.address else { return nil }
        return VerifyOnDeviceViewModel(isLedger: false,
                                       address: addressStr,
                                       isRedeposit: false,
                                       isDismissible: false)
    }
    func validateHW() async throws -> Bool {
        guard let address else {
            throw GaError.GenericError("Invalid address".localized)
        }
        return try await BleHwManager.shared.validateAddress(account: account, address: address)
    }
}
