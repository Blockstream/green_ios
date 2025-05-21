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

    var account: WalletItem { didSet { ReceiveViewModel.defaultAccount = account }}
    var asset: String
    var satoshi: Int64?
    var anyAsset: AnyAssetType?
    var isFiat: Bool = false
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

    static func getLightningSubaccounts() -> [WalletItem] {
        if let subaccount = WalletManager.current?.lightningSubaccount {
            return [subaccount]
        } else {
            return []
        }
    }
    static func getBitcoinSubaccounts() -> [WalletItem] {
        WalletManager.current?.bitcoinSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    static func getLiquidSubaccounts() -> [WalletItem] {
        WalletManager.current?.liquidSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    static func getLiquidAmpSubaccounts() -> [WalletItem] {
        WalletManager.current?.liquidAmpSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }

    init() {
        self.account = ReceiveViewModel.defaultAccount ?? ReceiveViewModel.getBitcoinSubaccounts().first!
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
        let hasSubaccountAmp = hasSubaccountAmp()
        let hasLighting = wm.existDerivedLightning()
        let assetIds = WalletManager.current?.registry.all
            .filter { !(!hasSubaccountAmp && $0.amp == true) }
            .filter { hasLighting || $0.assetId != AssetInfo.lightningId }
            .map { $0.assetId }
        let list = AssetAmountList.from(assetIds: assetIds ?? [])
        return AssetSelectViewModel(
            assets: list,
            enableAnyLiquidAsset: true,
            enableAnyAmpAsset: hasSubaccountAmp)
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

    func getAccounts() -> [WalletItem] {
        switch anyAsset {
        case .liquid:
            return ReceiveViewModel.getLiquidSubaccounts()
        case .amp:
            return ReceiveViewModel.getLiquidAmpSubaccounts()
        case nil:
            break
        }
        let asset = wm.info(for: asset)
        if asset.isLightning {
            return ReceiveViewModel.getLightningSubaccounts()
        } else if asset.isBitcoin {
            return ReceiveViewModel.getBitcoinSubaccounts()
        } else if asset.amp ?? false {
            return ReceiveViewModel.getLiquidAmpSubaccounts()
        } else {
            return ReceiveViewModel.getLiquidSubaccounts()
        }
    }

    func dialogAccountsModel() -> DialogAccountsViewModel {
        return DialogAccountsViewModel(
            title: "Account Selector",
            hint: "Select the desired account you want to receive your funds.".localized,
            isSelectable: true,
            assetId: asset,
            accounts: getAccounts(),
            hideBalance: hideBalance)
    }

    var hideBalance: Bool {
        get {
            return UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue)
        }
    }

    var receiveAssetCellModel: ReceiveAssetCellModel {
        ReceiveAssetCellModel(assetId: asset, anyAsset: anyAsset)
    }
    static var defaultAccountLabel: String? {
        guard let wm = WalletManager.current else { return nil }
        return "\(wm.account.id)_receive_subaccount"
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
}
