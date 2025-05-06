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
    var anyAsset: AnyAssetType?
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
    var backupCardCellModel = [AlertCardCellModel]()

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
        return try await BleHwManager.shared.validateAddress(account: account, address: address)
    }

    func receiveVerifyOnDeviceViewModel() -> HWDialogVerifyOnDeviceViewModel? {
        guard let address = address?.address else { return nil }
        let account = AccountsRepository.shared.current
        return HWDialogVerifyOnDeviceViewModel(isLedger: account?.isLedger ?? false,
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
        return AmountCellModel(satoshi: satoshi,
                               maxLimit: nodeState?.maxReceivableSatoshi,
                               isFiat: isFiat,
                               inputDenomination: inputDenomination,
                               gdkNetwork: account.session?.gdkNetwork,
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
        return ReceiveAddressCellModel(text: text,
                                       type: type,
                                       swapInfo: swap,
                                       satoshi: satoshi,
                                       maxLimit: nodeState?.maxReceivableSatoshi,
                                       inputDenomination: inputDenomination,
                                       nodeState: nodeState,
                                       breezSdk: account.lightningSession?.lightBridge,
                                       textNoURI: textNoURI,
                                       isLightning: account.gdkNetwork.lightning
        )
    }

    func getAssetSelectViewModel() -> AssetSelectViewModel {
        let assetIds = WalletManager.current?.registry.all.map { $0.assetId }
        let list = AssetAmountList.from(assetIds: assetIds ?? [])
        return AssetSelectViewModel(
            assets: list,
            enableAnyLiquidAsset: true,
            enableAnyAmpAsset: true)
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
    func reloadBackupCards() {
        var cards: [AlertCardType] = []
        if BackupHelper.shared.needsBackup(walletId: wm.account.id) && BackupHelper.shared.isDismissed(walletId: wm.account.id, position: .receive) == false {
            cards.append(.backup)
        }
        self.backupCardCellModel = cards.map { AlertCardCellModel(type: $0) }
    }
    func hasSubaccountAmp() -> Bool {
        !wm.subaccounts.filter({ $0.type == .amp }).isEmpty
    }
    func createSubaccountAmp() async throws {
        guard let session = wm.liquidMultisigSession else {
            throw GaError.GenericError("Invalid session".localized)
        }
        try await session.connect()
        if !session.logged {
            if let device = wm.hwDevice {
                try await session.register(credentials: nil, hw: device)
                _ = try await session.loginUser(credentials: nil, hw: device)
            } else {
                let credentials = try await wm.prominentSession?.getCredentials(password: "")
                try await session.register(credentials: credentials, hw: nil)
                _ = try await session.loginUser(credentials: credentials, hw: nil)
            }
        }
        _ = try await session.createSubaccount(CreateSubaccountParams(name: "", type: .amp))
        _ = try await session.updateSubaccount(UpdateSubaccountParams(subaccount: 0, hidden: false))
        _ = try await wm.subaccounts()
    }
    func getLightningSubaccounts() -> [WalletItem] {
        wm.subaccounts.filter { !$0.hidden && $0.networkType.lightning }
    }
    func getBitcoinSubaccounts() -> [WalletItem] {
        wm.subaccounts.filter { !$0.hidden && !$0.networkType.liquid && !$0.networkType.lightning }
    }
    func getLiquidSubaccounts() -> [WalletItem] {
        wm.subaccounts.filter { !$0.hidden && $0.networkType.liquid }
    }
    func getLiquidAmpSubaccounts() -> [WalletItem] {
        wm.subaccounts.filter { !$0.hidden && $0.networkType.liquid && $0.type == .amp }
    }

    func dialogAccountsModel() -> DialogAccountsViewModel {
        return DialogAccountsViewModel(
            title: "Account Selector",
            hint: "Select the desired account you want to receive your funds.".localized,
            isSelectable: true,
            assetId: asset,
            accounts: accounts,
            hideBalance: hideBalance)
    }

    var hideBalance: Bool {
        get {
            return UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue)
        }
    }

    var walletAssetCellModel: WalletAssetCellModel {
        WalletAssetCellModel(assetId: asset, satoshi: 0, masked: hideBalance, hidden: true)
    }
}
