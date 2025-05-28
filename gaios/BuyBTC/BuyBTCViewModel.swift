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
    var account: WalletItem { didSet { ReceiveViewModel.defaultAccount = account }}
    var inputDenomination: gdk.DenominationType = .Sats
    var state: AmountCellState = .invalidBuy
    var meld: Meld
    var wm: WalletManager { WalletManager.current! }
    var swapInfo: SwapInfo?
    var backupCardCellModel = [AlertCardCellModel]()
    var currency: String?
    var tiers: Tiers?
    var hideBalance = false
    var showNoQuotes: Bool {
        false
    }
    var showAccountSwitch: Bool {
        getAccounts().count > 1
    }
    static func getBitcoinSubaccounts() -> [WalletItem] {
        WalletManager.current?.bitcoinSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    var address: Address?
    var dialogAccountsModel: DialogAccountsViewModel {
        return DialogAccountsViewModel(
            title: "Account Selector",
            hint: "Select the desired account you want to receive your bitcoin.".localized,
            isSelectable: true,
            assetId: AssetInfo.btcId,
            accounts: getAccounts(),
            hideBalance: hideBalance)
    }
    init(currency: String?,
         hideBalance: Bool = false) {
        self.account = BuyBTCViewModel.defaultAccount ?? BuyBTCViewModel.getBitcoinSubaccounts().first!
        self.asset = account.gdkNetwork.getFeeAsset()
        self.meld = Meld()
        self.inputDenomination = WalletManager.current?.prominentSession?.settings?.denomination ?? .Sats
        self.hideBalance = hideBalance
        self.currency = currency
        self.loadTiers()
    }
    var isJade: Bool { wm.account.isJade }
    func quote(_ amountStr: String) async throws -> [MeldQuoteItem] {
        let amt = amountStr.replacingOccurrences(of: ",", with: ".")
        let params = MeldQuoteParams(
            destinationCurrencyCode: "BTC",
            countryCode: countryCode(),
            sourceAmount: amt,
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
        let amt = amountStr.replacingOccurrences(of: ",", with: ".")
        guard let addressStr = address?.address else {
           throw GaError.GenericError("Invalid address")
        }
        let sessionParams = MeldSessionParams(
            serviceProvider: quote.serviceProvider,
            countryCode: countryCode(),
            destinationCurrencyCode: "BTC",
            lockFields: ["destinationCurrencyCode",
                         "walletAddress",
                         "sourceCurrencyCode"],
            paymentMethodType: "CARD",
            // redirectUrl: "",
            sourceAmount: amt,
            sourceCurrencyCode: currency ?? "USD",
            walletAddress: addressStr)
        let params = MeldWidgetParams(
            sessionData: sessionParams,
            sessionType: MeldTransactionType.BUY.rawValue,
            externalCustomerId: wm.account.xpubHashId ?? "")
        return try await meld.widget(params)
    }
    func verifyOnDeviceViewModel() -> HWDialogVerifyOnDeviceViewModel? {
        guard let addressStr = address?.address else { return nil }
        return HWDialogVerifyOnDeviceViewModel(isLedger: false,
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
    func countryCode() -> String {
        if let cCode = UserDefaults.standard.string(forKey: AppStorageConstants.buyCountyCodeUserSelected.rawValue) {
            return cCode.uppercased()
        } else {
            return (Locale.current.regionCode ?? "US").uppercased()
        }
    }
    func persistCountry(_ cCode: String) {
        UserDefaults.standard.setValue(cCode, forKey: AppStorageConstants.buyCountyCodeUserSelected.rawValue)
    }
    func hasPendingTransactions() async throws -> Bool {
        guard let xpub = wm.account.xpubHashId else {
            return false
        }
        let hasPendingTx =  try await meld.getPendingTransactions(xpub: xpub).count > 0
        // enable fetching txs based on meld reply
        Meld.enableFetchingTxs(xpub: xpub, enable: hasPendingTx)
        return hasPendingTx
    }

    static var defaultAccountLabel: String? {
        guard let wm = WalletManager.current else { return nil }
        return "\(wm.account.id)_buy_subaccount"
    }

    static var defaultAccount: WalletItem? {
        get {
            guard let label = defaultAccountLabel else { return nil }
            let accountId = UserDefaults.standard.string(forKey: label)
            return WalletManager.current?.subaccounts.filter({ $0.id == accountId }).first
        }
        set {
            guard let label = defaultAccountLabel else { return }
            UserDefaults.standard.set(newValue?.id, forKey: label)
        }
    }
    
    func getBitcoinSubaccounts() -> [WalletItem] {
        wm.subaccounts.filter { !$0.hidden && !$0.networkType.liquid && !$0.networkType.lightning }.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 })
    }
    
    func getAccounts() -> [WalletItem] {
        return getBitcoinSubaccounts()
    }
    func checkUKRegion() -> Bool {
        return Locale.current.regionCode == "UK"
    }
}
