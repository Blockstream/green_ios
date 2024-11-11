import Foundation
import UIKit
import gdk
import greenaddress
import hw
import BreezSDK
import lightning
import core

class BuyViewModel {

    var asset: String
    var satoshi: Int64?
    var isFiat: Bool = true
    var account: WalletItem?
    var inputDenomination: gdk.DenominationType = .Sats
    var state: AmountToBuyCellState = .invalid
    var meld: Meld
    var wm: WalletManager { WalletManager.current! }
    var swapInfo: SwapInfo?

    init(account: WalletItem?) {
        self.account = account
        self.asset = account?.gdkNetwork.getFeeAsset() ?? "btc"
        self.meld = Meld.init(isSandboxEnvironment: WalletManager.current?.testnet ?? false)
        self.inputDenomination = WalletManager.current?.prominentSession?.settings?.denomination ?? .Sats
    }

    func accountType() -> String {
        return account?.localizedName ?? ""
    }

    func toBTC(_ satoshi: Int64) -> Double {
        return Double(satoshi) / 100000000
    }

    var assetCellModel: ReceiveAssetCellModel? {
        guard let account = account else { return nil }
        return ReceiveAssetCellModel(assetId: asset, account: account)
    }

    func dialogInputDenominationViewModel() -> DialogInputDenominationViewModel {
        let list: [DenominationType] = [ .BTC, .MilliBTC, .MicroBTC, .Bits, .Sats]
        let gdkNetwork = account?.session?.gdkNetwork
        let network: NetworkSecurityCase = gdkNetwork?.mainnet ?? true ? .bitcoinSS : .testnetSS
        return DialogInputDenominationViewModel(
            denomination: inputDenomination,
            denominations: list,
            network: network,
            isFiat: isFiat,
            balance: getBalance())
    }

    func getBalance() -> Balance? {
        return Balance.fromSatoshi(satoshi ?? 0.0, assetId: asset)
    }

    var amountCellModel: AmountToBuyCellModel {
        return AmountToBuyCellModel(satoshi: satoshi,
                                 isFiat: isFiat,
                                 inputDenomination: inputDenomination,
                                 network: account?.session?.networkType,
                                 swapInfo: swapInfo
        )
    }

    func accountAssetViewModel(for type: MeldTransactionType) -> AccountAssetViewModel {
        var subaccounts = type == .BUY ? wm.bitcoinSubaccounts : wm.bitcoinSubaccountsWithFunds
        if let lightningSubaccount = wm.lightningSubaccount {
            subaccounts.append(lightningSubaccount)
        }
        return AccountAssetViewModel(
            accounts: subaccounts,
            createTx: nil,
            funded: false,
            showBalance: false)
    }

    func load() async throws {
        swapInfo = try? wm.lightningSession?.lightBridge?.receiveOnchain()
    }

    func buy() async throws -> String {
        guard let pointer = account?.pointer else {
            throw GaError.GenericError("Invalid account")
        }
        let address = try await account?.session?.getReceiveAddress(subaccount: pointer)
        let ticker = wm.info(for: asset).ticker
        let balance = Balance.fromSatoshi(satoshi, assetId: asset)
        guard let address = address?.address else {
           throw GaError.GenericError("Invalid address")
        }
        return meld.buyUrl(walletAddressLocked: address, destinationCurrencyCodeLocked: ticker ?? "BTC", sourceAmount: balance?.fiat ?? "200", sourceCurrencyCode: balance?.fiatCurrency ?? "USD")
    }
}
