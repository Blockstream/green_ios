import Foundation
import UIKit
import gdk
import greenaddress
import hw
import BreezSDK
import lightning
import core
import LiquidWalletKit

enum ReceiveType: Int, CaseIterable {
    case address
    case breezSwap
    case bolt11
    case lwkSwap
}

class ReceiveViewModel {

    var account: WalletItem { didSet { ReceiveViewModel.defaultAccount = account }}
    var mainAccount: Account? { AccountsRepository.shared.current }
    var asset: String
    var satoshi: Int64?
    var anyAsset: AnyAssetType?
    var isFiat: Bool = false
    var type: ReceiveType
    var description: String?
    var address: gdk.Address?
    var receivePaymentResponse: ReceivePaymentResponse?
    var breezInvoice: LnInvoice? { receivePaymentResponse?.lnInvoice }
    var lwkInvoice: InvoiceResponse?
    var bolt11: String?
    var breezSwap: SwapInfo?
    var inputDenomination: gdk.DenominationType = .Sats
    var state: AmountCellState = .disabled
    var wm: WalletManager { WalletManager.current! }
    var backupCardCellModel = [AlertCardCellModel]()
    var allowChange = true
    var reverseSwapInfo: BoltzReverseSwapInfoLBTC?

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
    init(_ waParam: (wallet: WalletItem, assetId: String)? = nil) {
        if let waParam = waParam {
            self.account = waParam.wallet
            self.asset = waParam.assetId
            self.allowChange = false
        } else {
            self.account = ReceiveViewModel.defaultAccount ?? ReceiveViewModel.getBitcoinSubaccounts().first ??  ReceiveViewModel.getLiquidSubaccounts().first!
            self.asset = self.account.gdkNetwork.getFeeAsset()
        }
        self.type = self.asset == AssetInfo.lightningId ? .bolt11 : .address
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
            if satoshi == nil {
                return
            }
            receivePaymentResponse = try await wm.lightningSession?.createInvoice(satoshi: UInt64(satoshi ?? 0), description: description ?? "")
            bolt11 = receivePaymentResponse?.lnInvoice.bolt11
        case .lwkSwap:
            let liquidAccount: WalletItem? = {
                if self.account.networkType.liquid {
                    return self.account
                }
                return self.wm.liquidSubaccounts.first
            }()
            guard let account = liquidAccount else {
                throw GaError.GenericError("No liquid session")
            }
            logger.info("BOLTZ getReceiveAddress")
            let address = try await account.session?.getReceiveAddress(subaccount: account.pointer)
            guard let address = address?.address else {
                throw GaError.GenericError("Invalid address")
            }
            logger.info("BOLTZ invoice")
            let claimAddress = try LiquidWalletKit.Address(s: address)
            let invoice = try await wm.lwkSession?.invoice(amount: UInt64(satoshi ?? 0), description: description ?? "", claimAddress: claimAddress)
            self.lwkInvoice = invoice
            self.bolt11 = try invoice?.bolt11Invoice().description
            logger.info("BOLTZ invoiced")
        case .breezSwap:
            breezSwap = try await wm.lightningSession?.lightBridge?.receiveOnchain()
        }
    }

    func isBipAddress(_ addr: String) -> Bool {
        let session = wm.sessions[account.gdkNetwork.network]
        return session?.validBip21Uri(uri: addr) ?? false
    }

    func validateHW() async throws -> Bool {
        guard let address = address else {
            throw GaError.GenericError("id_invalid_address".localized)
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

    func addressToUri(address: String, satoshi: Int64?, assetId: String?) -> String {
        var params = [String]()
        if let satoshi = satoshi, satoshi > 0 {
            let amount = String(format: "%.8f", toBTC(satoshi))
            params += ["amount=\(amount)"]
        }
        if let assetId = assetId {
            if account.gdkNetwork.liquid && satoshi ?? 0 > 0 {
                params += ["assetid=\(assetId)"]
            } else if !AssetInfo.baseIds.contains(assetId) {
                params += ["assetid=\(assetId)"]
            }
        }
        let bip21Prefix = account.gdkNetwork.bip21Prefix ?? ""
        return "\(bip21Prefix):\(address)?\(params.joined(separator: "&"))"
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
                               scope: self.type == .lwkSwap ? .reverseSwap : .ltReceive,
                               reverseSwapInfo: reverseSwapInfo
        )
    }

    var infoReceivedAmountCellModel: LTInfoCellModel {
        /*if let satoshi = invoice?.receiveAmountSatoshi(openingFeeParams: receivePaymentResponse?.openingFeeParams) {
            if let balance = Balance.fromSatoshi(Int64(satoshi), assetId: "btc") {
                let (value, denom) = balance.toDenom(inputDenomination)
                let (fiat, currency) = balance.toFiat()
                return LTInfoCellModel(title: "id_amount_to_receive".localized, hint1: "\(value) \(denom)", hint2: "\(fiat) \(currency)")
            }
        }*/
        return LTInfoCellModel(title: "id_amount_to_receive".localized, hint1: "", hint2: "")
    }

    var infoExpiredInCellModel: LTInfoCellModel {
        LTInfoCellModel(
            title: "id_expiration".localized,
            hint1: "", //"In \(abs(invoice?.expiringInMinutes ?? 0)) minutes",
            hint2: "")
    }

    var noteCellModel: LTNoteCellModel {
        return LTNoteCellModel(note: description ?? "id_note".localized)
    }

    var isBip21: Bool {
        return text?.hasPrefix("bitcoin:") ?? false ||
            text?.hasPrefix("lightning:") ?? false ||
            text?.hasPrefix("liquidnetwork:") ?? false
    }

    var text: String? {
        switch type {
        case .bolt11:
            return bolt11
        case .breezSwap:
            return breezSwap?.bitcoinAddress
        case .lwkSwap:
            return bolt11
        case .address:
            if let address = address?.address {
                if !AssetInfo.baseIds.contains(where: { $0 == asset}) {
                    return addressToUri(address: address, satoshi: satoshi ?? 0, assetId: asset)
                } else if satoshi != nil {
                    return addressToUri(address: address, satoshi: satoshi ?? 0, assetId: asset)
                } else {
                    return address
                }
            }
            return nil
        }
    }

    var addressCellModel: ReceiveAddressCellModel {
        let nodeState = account.lightningSession?.nodeState
        return ReceiveAddressCellModel(text: text,
                                       isBip21: isBip21,
                                       type: type,
                                       swapInfo: breezSwap,
                                       satoshi: satoshi,
                                       maxLimit: nodeState?.maxReceivableSatoshi,
                                       inputDenomination: inputDenomination,
                                       nodeState: nodeState,
                                       breezSdk: account.lightningSession?.lightBridge,
                                       isLightning: account.gdkNetwork.lightning
        )
    }

    func getAssetSelectViewModel() -> AssetSelectViewModel {
        let hasSubaccountAmp = hasSubaccountAmp()
        let hasLightning = wm.lightningSession?.logged ?? false
        let hasLiquid = hasSubaccountLiquid()
        let hasBitcoin = hasSubaccountBitcoin()
        let assetIds = WalletManager.current?.registry.all
            .filter { !(!hasSubaccountAmp && $0.amp == true) }
            .filter { hasLightning || $0.assetId != AssetInfo.lightningId }
            .filter { hasBitcoin || ![AssetInfo.btcId, AssetInfo.testId].contains($0.assetId) }
            .filter { hasLiquid || [AssetInfo.btcId, AssetInfo.testId, AssetInfo.lightningId].contains($0.assetId) }
            .map { $0.assetId }
        let list = AssetAmountList.from(assetIds: assetIds ?? [])
        return AssetSelectViewModel(
            assets: list,
            enableAnyLiquidAsset: hasLiquid,
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
        if BackupHelper.shared.needsBackup(walletId: mainAccount?.id) && BackupHelper.shared.isDismissed(walletId: mainAccount?.id, position: .receive) == false {
            cards.append(.backup)
        }
        self.backupCardCellModel = cards.map { AlertCardCellModel(type: $0) }
    }
    func hasSubaccountAmp() -> Bool {
        !wm.subaccounts.filter({ $0.type == .amp }).isEmpty
    }
    func hasSubaccountLiquid() -> Bool {
        !wm.subaccounts.filter({ $0.networkType.liquid }).isEmpty
    }
    func hasSubaccountBitcoin() -> Bool {
        !wm.subaccounts.filter({ $0.networkType.bitcoin }).isEmpty
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
        if type == .lwkSwap {
            return ReceiveViewModel.getLiquidSubaccounts()
        } else if asset.isLightning {
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
            title: "id_account_selector".localized,
            hint: "id_choose_which_account_you_want".localized,
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
        return "\(AccountsRepository.shared.current?.id ?? "")_receive_subaccount"
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
