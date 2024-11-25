import Foundation
import UIKit
import gdk
import greenaddress
import hw
import BreezSDK
import lightning
import core

enum ReceiveType: Int, CaseIterable {
    case address
    case swap
    case bolt11
}

class ReceiveViewModel {

    var accounts: [WalletItem]
    var asset: String
    var satoshi: Int64?
    var isFiat: Bool = false
    var account: WalletItem
    var type: ReceiveType
    var description: String?
    var address: Address?
    var receivePaymentResponse: ReceivePaymentResponse?
    var invoice: LnInvoice? { receivePaymentResponse?.lnInvoice }
    var swap: SwapInfo?
    var inputDenomination: gdk.DenominationType = .Sats
    var state: AmountCellState = .disabled

    var wm: WalletManager { WalletManager.current! }

    init(account: WalletItem, accounts: [WalletItem]) {
        self.account = account
        self.accounts = accounts
        self.asset = account.gdkNetwork.getFeeAsset()
        self.type = account.gdkNetwork.lightning ? .bolt11 : .address
        self.inputDenomination = wm.prominentSession?.settings?.denomination ?? .Sats
    }

    func accountType() -> String {
        return account.localizedName
    }

    func newAddress() async throws {
        switch type {
        case .address:
            address = nil
            let session = self.wm.sessions[account.gdkNetwork.network]
            address = try await session?.getReceiveAddress(subaccount: account.pointer)
        case .bolt11:
            receivePaymentResponse = nil
            if satoshi == nil {
                return
            }
            receivePaymentResponse = try await wm.lightningSession?.createInvoice(satoshi: UInt64(satoshi ?? 0), description: description ?? "")
        case .swap:
            swap = try await wm.lightningSession?.lightBridge?.receiveOnchain()
        }
    }

    func isBipAddress(_ addr: String) -> Bool {
        let session = wm.sessions[account.gdkNetwork.network]
        return session?.validBip21Uri(uri: addr) ?? false
    }

    func validateHW() async throws -> Bool {
        guard let address = address else {
            throw GaError.GenericError("Invalid address".localized)
        }
        return try await BleViewModel.shared.validateAddress(account: account, address: address)
    }

    func receiveVerifyOnDeviceViewModel() -> VerifyOnDeviceViewModel? {
        guard let address = address?.address else { return nil }
        let account = AccountsRepository.shared.current
        return VerifyOnDeviceViewModel(isLedger: account?.isLedger ?? false,
                                       address: address,
                                       isRedeposit: false,
                                       isDismissible: false)
    }

    func addressToUri(address: String, satoshi: Int64, assetId: String) -> String {
        var ntwPrefix = "bitcoin"
        if account.gdkNetwork.liquid {
            ntwPrefix = account.gdkNetwork.mainnet ? "liquidnetwork" :  "liquidtestnet"
        }
        let amount = String(format: "%.8f", toBTC(satoshi))
        if satoshi == 0 {
            return address
        } else if !account.gdkNetwork.liquid {
            return "\(ntwPrefix):\(address)?amount=\(amount)"
        } else {
            return "\(ntwPrefix):\(address)?amount=\(amount)&assetid=\(assetId)"
        }
    }

    func toBTC(_ satoshi: Int64) -> Double {
        return Double(satoshi) / 100000000
    }

    var amountCellModel: AmountCellModel {
        let nodeState = account.lightningSession?.nodeState
        let lspInfo = account.lightningSession?.lspInfo
        return AmountCellModel(satoshi: satoshi,
                               maxLimit: nodeState?.maxReceivableSatoshi,
                               isFiat: isFiat,
                               inputDenomination: inputDenomination,
                               gdkNetwork: account.session?.gdkNetwork,
                               nodeState: nodeState,
                               lspInfo: lspInfo,
                               breezSdk: account.lightningSession?.lightBridge,
                               scope: .ltReceive
        )
    }

    var infoReceivedAmountCellModel: LTInfoCellModel {
        if let satoshi = invoice?.receiveAmountSatoshi(openingFeeParams: receivePaymentResponse?.openingFeeParams) {
            if let balance = Balance.fromSatoshi(Int64(satoshi), assetId: "btc") {
                let (value, denom) = balance.toDenom(inputDenomination)
                let (fiat, currency) = balance.toFiat()
                return LTInfoCellModel(title: "id_amount_to_receive".localized, hint1: "\(value) \(denom)", hint2: "\(fiat) \(currency)")
            }
        }
        return LTInfoCellModel(title: "id_amount_to_receive".localized, hint1: "", hint2: "")
    }

    var infoExpiredInCellModel: LTInfoCellModel {
        LTInfoCellModel(
            title: "id_expiration".localized,
            hint1: "In \(abs(invoice?.expiringInMinutes ?? 0)) minutes",
            hint2: "")
    }

    var noteCellModel: LTNoteCellModel {
        return LTNoteCellModel(note: description ?? "id_note".localized)
    }

    var assetCellModel: ReceiveAssetCellModel {
        return ReceiveAssetCellModel(assetId: asset, account: account)
    }

    var text: String? {
        switch type {
        case .bolt11:
            if let txt = invoice?.bolt11 {
                return "lightning:\( (txt).uppercased() )"
            }
            return nil
        case .swap:
            return swap?.bitcoinAddress
        case .address:
            var text = address?.address
            if let address = address?.address, let satoshi = satoshi {
                text = addressToUri(address: address, satoshi: satoshi, assetId: asset)
            }
            return text
        }
    }

    var textNoURI: String? {
        switch type {
        case .bolt11:
            if let txt = invoice?.bolt11 {
                return "\( (txt).uppercased() )"
            }
            return nil
        case .swap:
            return swap?.bitcoinAddress
        case .address:
            return address?.address
        }
    }

    var addressCellModel: ReceiveAddressCellModel {
        let nodeState = account.lightningSession?.nodeState
        let lspInfo = account.lightningSession?.lspInfo
        return ReceiveAddressCellModel(text: text,
                                       type: type,
                                       swapInfo: swap,
                                       satoshi: satoshi,
                                       maxLimit: nodeState?.maxReceivableSatoshi,
                                       inputDenomination: inputDenomination,
                                       nodeState: nodeState,
                                       lspInfo: lspInfo,
                                       breezSdk: account.lightningSession?.lightBridge,
                                       textNoURI: textNoURI,
                                       isLightning: account.gdkNetwork.lightning
        )
    }

    func getAssetSelectViewModel() -> AssetSelectViewModel {
        let isLiquid = account.gdkNetwork.liquid
        let showAmp = accounts.filter { $0.type == .amp }.count > 0
        let showLiquid = accounts.filter { $0.gdkNetwork.liquid }.count > 0
        let showBtc = accounts.filter { !$0.gdkNetwork.liquid }.count > 0
        let assets = WalletManager.current?.registry.all
            .filter {
                (showAmp && $0.amp ?? false) ||
                (showLiquid && $0.assetId != AssetInfo.btcId) ||
                (showBtc && $0.assetId == AssetInfo.btcId)
            }
        let list = AssetAmountList.from(assetIds: assets?.map { $0.assetId } ?? [])

        // TODO: handle amp case
        return AssetSelectViewModel(assets: list,
                                    enableAnyLiquidAsset: isLiquid,
                                    enableAnyAmpAsset: isLiquid)
    }

    func getAssetExpandableSelectViewModel() -> AssetExpandableSelectViewModel {
        let isWO = AccountsRepository.shared.current?.isWatchonly ?? false
        let isLiquid = account.gdkNetwork.liquid
        let hideLiquid = isWO && !isLiquid
        let hideBtc = isWO && isLiquid
        return AssetExpandableSelectViewModel(
            enableAnyLiquidAsset: !hideLiquid,
            enableAnyAmpAsset: !hideLiquid,
            hideLiquid: hideLiquid,
            hideBtc: hideBtc)
    }

    func dialogInputDenominationViewModel() -> DialogInputDenominationViewModel {
        let list: [DenominationType] = [ .BTC, .MilliBTC, .MicroBTC, .Bits, .Sats]
        let gdkNetwork = account.session?.gdkNetwork
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

    func ltSuccessViewModel(details: InvoicePaidDetails) async throws -> LTSuccessViewModel? {
        let satoshi = details.payment?.amountSatoshi
        if let balance = Balance.fromSatoshi(satoshi ?? 0, assetId: AssetInfo.btcId) {
            let (amount, denom) = balance.toDenom(inputDenomination)
            return LTSuccessViewModel(account: account.name, amount: amount, denom: denom)
        }
        return nil
    }

}
