import Foundation
import core
import gdk
import LiquidWalletKit
import greenaddress

enum ReceiveType: Sendable, Equatable {
    case address
    case bolt11
    case lwkSwap
}
enum RefreshReceiveFeature: Sendable, Hashable {
    case denomination
    case segmented
    case address
    case paymentReady
    case error(String)
}
@MainActor
final class ReceiveViewModel: Sendable {
    var walletDataModel: WalletDataModel
    var wm: WalletManager { walletDataModel.wallet }
    let mainAccount: Account
    weak var delegate: ReceiveViewModelDelegate?
    private let receiveService: ReceiveService

    // Tasks
    private var addressTask: Task<Void, Never>?
    private var paymentTask: Task<Void, Never>?
    private var reverseSwapTask: Task<Void, Never>?

    // UI state
    private(set) var state: ReceiveState
    // Callback for UI updates
    var onUpdate: (@MainActor @Sendable (RefreshReceiveFeature?) -> Void)?
    init(
        mainAccount: Account,
        walletDataModel: WalletDataModel,
        subaccount: WalletItem,
        anyOrAsset: AnyOrAsset,
        delegate: ReceiveViewModelDelegate? = nil,
        receiveService: ReceiveService = ReceiveService(),
        onUpdate: (@MainActor @Sendable (RefreshReceiveFeature?) -> Void)? = nil,
    ) {
        self.mainAccount = mainAccount
        self.delegate = delegate
        self.receiveService = receiveService
        self.walletDataModel = walletDataModel

        let type: ReceiveType = anyOrAsset.assetId == AssetInfo.lightningId ? .bolt11 : .address
        self.state = ReceiveState(
            subaccount: subaccount,
            type: type,
            anyOrAsset: anyOrAsset,
            inputDenomination: walletDataModel.wallet.prominentSession?.settings?.denomination ?? .Sats
        )
        self.onUpdate = onUpdate
    }
    deinit {
        addressTask?.cancel()
        paymentTask?.cancel()
        reverseSwapTask?.cancel()
    }
    func prepareReverseSwap() {
        reverseSwapTask?.cancel()
        reverseSwapTask = Task { [weak self] in
            guard let self else { return }
            do {
                if self.state.reverseSwapInfo == nil {
                    let response = try await self.receiveService.fetchReverseSwapInfo(
                        .init(walletManager: self.wm))
                    guard !Task.isCancelled else { return }
                    self.state.reverseSwapInfo = response.info
                }
                guard !Task.isCancelled else { return }
                self.state.type = .lwkSwap
                self.state.selectedSegment = 1
                self.onUpdate?(.segmented)
            } catch is CancellationError {
                self.onUpdate?(nil)
                return
            } catch {
                self.onUpdate?(.error(error.description()))
            }
        }
    }
    func selectAddressMode() {
        reverseSwapTask?.cancel()
        paymentTask?.cancel()
        state.type = .address
        state.satoshi = nil
        state.selectedSegment = 0
        onUpdate?(.segmented)
    }
    func selectReverseSwapMode() {
        state.satoshi = nil
        prepareReverseSwap()
    }
    func setAmount(_ satoshi: Int64?, feature: RefreshReceiveFeature? = nil) {
        paymentTask?.cancel()
        state.satoshi = satoshi
        onUpdate?(feature)
    }
    func newAddress() {
        addressTask?.cancel()
        let subaccount = state.subaccount
        let walletManager = wm
        addressTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.receiveService.buildAddress(
                    .init(subaccount: subaccount, walletManager: walletManager))
                guard !Task.isCancelled else { return }
                self.state.address = response.address
                self.onUpdate?(.address)
            } catch is CancellationError {
                self.onUpdate?(nil)
                return
            } catch {
                self.onUpdate?(.error(error.description()))
            }
        }
    }
    func newPayment() {
        paymentTask?.cancel()
        let type = state.type
        let satoshi = UInt64(state.satoshi ?? 0)
        let description = state.description ?? ""
        let walletManager = wm
        let subaccount = state.subaccount
        paymentTask = Task { [weak self] in
            guard let self else { return }
            do {
                switch type {
                case .address:
                    return
                case .bolt11:
                    let response = try await self.receiveService.createLightningInvoice(
                        .init(
                            walletManager: walletManager,
                            satoshi: satoshi,
                            description: description))
                    guard !Task.isCancelled else { return }
                    self.state.lightningReceivePayment = response.payment
                    self.state.bolt11 = response.bolt11
                    self.onUpdate?(.paymentReady)
                case .lwkSwap:
                    let response = try await self.receiveService.createReverseSwapInvoice(
                        .init(
                            subaccount: subaccount,
                            walletManager: walletManager,
                            satoshi: satoshi,
                            description: description))
                    guard !Task.isCancelled else { return }
                    self.state.lwkInvoice = response.invoice
                    self.state.bolt11 = response.bolt11
                    self.onUpdate?(.paymentReady)
                }
            } catch is CancellationError {
                self.onUpdate?(nil)
                return
            } catch {
                self.onUpdate?(.error(error.description()))
            }
        }
    }
    func dismissBackupCard() {
        BackupHelper.shared.addToDismissed(walletId: mainAccount.id, position: .receive)
        onUpdate?(nil)
    }
    func editNote() {
        delegate?.editNote(vm: self, description: state.description ?? "")
    }
    func updateNote(_ note: String) {
        paymentTask?.cancel()
        state.description = note
        onUpdate?(nil)
    }
    func onFundingFee() {
        delegate?.fundingFee()
    }
    func onShowInvoice() {
        let model = LNInvoiceViewModel(satoshi: state.satoshi ?? 0,
                                         description: state.description ?? "",
                                         account: state.subaccount,
                                         walletDataModel: walletDataModel,
                                         type: state.type,
                                         inputDenomination: state.inputDenomination,
                                         lightningReceivePayment: state.lightningReceivePayment,
                                         lwkInvoice: state.lwkInvoice,
                                         bolt11: state.bolt11 ?? ""
        )
        delegate?.invoice(model)
    }
    func onInputDenomination() {
        let list: [DenominationType] = [ .BTC, .MilliBTC, .MicroBTC, .Bits, .Sats]
        let gdkNetwork = state.subaccount.session?.gdkNetwork
        let network: NetworkSecurityCase = gdkNetwork?.mainnet ?? true ? .bitcoinSS : .testnetSS
        let model = DialogInputDenominationViewModel(
            denomination: state.inputDenomination,
            denominations: list,
            network: network,
            isFiat: state.isFiat,
            balance: Balance.fromSatoshi(state.satoshi ?? Int64(0), assetId: state.anyOrAsset.assetId))
        delegate?.denominationSelector(vm: self, model: model)
    }
    func onAddressAuth() {
        let model = AddressAuthViewModel(wallet: state.subaccount)
        delegate?.addressAuth(model)
    }
    func onManualBackup() {
        let model = ManualBackupViewModel(.quiz)
        delegate?.manualBackup(model)
    }
    func onSend() {
        delegate?.send(subaccount: state.subaccount, anyOrAsset: state.anyOrAsset)
    }
    func onAmountFieldChange(_ txt: String) {
        setAmount(state.getSatoshi(txt))
    }
    func selectFiat() {
        paymentTask?.cancel()
        state.isFiat = true
        onUpdate?(nil)
    }
    func selectDenomination(_ denom: gdk.DenominationType) {
        paymentTask?.cancel()
        state.isFiat = false
        state.inputDenomination = denom
        onUpdate?(.denomination)
    }
    func receiveVerifyOnDeviceViewModel() -> HWDialogVerifyOnDeviceViewModel? {
        guard let address = state.address?.address else { return nil }
        let account = AccountsRepository.shared.current
        return HWDialogVerifyOnDeviceViewModel(isLedger: account?.isLedger ?? false,
                                               address: address,
                                               isRedeposit: false,
                                               isDismissible: false)
    }
    func validateHW() async throws -> Bool {
        guard let address = state.address else {
            throw GaError.GenericError("id_invalid_address".localized)
        }
        return try await BleHwManager.shared.validateAddress(account: state.subaccount, address: address)
    }
    func isBipAddress(_ addr: String) -> Bool {
        let session = wm.sessions[state.subaccount.gdkNetwork.network]
        return session?.validBip21Uri(uri: addr) ?? false
    }
    func getLightningSubaccounts() -> [WalletItem] {
        if let subaccount = WalletManager.current?.lightningSubaccount {
            return [subaccount]
        } else {
            return []
        }
    }
    func getBitcoinSubaccounts() -> [WalletItem] {
        WalletManager.current?.bitcoinSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    func getLiquidSubaccounts() -> [WalletItem] {
        WalletManager.current?.liquidSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    func getLiquidAmpSubaccounts() -> [WalletItem] {
        WalletManager.current?.liquidAmpSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    func getAccounts() -> [WalletItem] {
        switch state.anyOrAsset {
        case .anyLiquid:
            return getLiquidSubaccounts()
        case .anyAmp:
            return getLiquidAmpSubaccounts()
        case .asset(let assetId):
            let asset = wm.info(for: assetId)
            if state.type == .lwkSwap {
                return getLiquidSubaccounts()
            } else if asset.isLightning {
                return getLightningSubaccounts()
            } else if asset.isBitcoin {
                return getBitcoinSubaccounts()
            } else if asset.amp ?? false {
                return getLiquidAmpSubaccounts()
            } else {
                return getLiquidSubaccounts()
            }
        }
    }
    var maxLimit: UInt64? {
        return wm.lightningSession?.nodeState()?.totalInboundLiquidityMsat.satoshi
    }
    var hasActiveChannel: Bool {
        wm.lightningSession?.nodeState()?.numActiveChannels ?? 0 > 0
    }
    var showAccount: Bool {
        return getAccounts().count > 1
    }
    var hasLwkSession: Bool {
        return wm.lwkSession?.logged ?? false
    }
    var showSegmented: Bool {
        if state.anyOrAsset.assetId != AssetInfo.lbtcId { return false }
        if state.type == .lwkSwap { return true }
        if wm.lwkSession?.logged ?? false {
            switch state.anyOrAsset {
            case .anyLiquid, .anyAmp:
                return false
            default:
                return true
            }
        } else {
            return false
        }
    }
    var maxLimitAmount: String? {
        if let maxLimit = maxLimit {
            let balance = Balance.fromSatoshi(UInt64(maxLimit), assetId: AssetInfo.btcId)
            return state.isFiat ? balance?.toFiat().0 : balance?.toDenom(state.inputDenomination).0
        }
        return nil
    }

    var fieldState: AmountFieldState {
        guard let satoshi = state.satoshi else { return .disabled }
        switch state.scope {
        case .ltReceive:
            if satoshi > state.lnMaxSatoshis {
                return .lnAboveMax
            }
            if hasActiveChannel && satoshi > maxLimit ?? 0 {
                // amount above inbound liquidity
                if satoshi < state.lnRecommendedSatoshis {
                    return .lnRecommend
                } else {
                    return .lnShowFunding
                }
            }
            if !hasActiveChannel {
                if satoshi < state.lnMinSatoshis {
                    return .lnBelowMin
                } else if satoshi >= state.lnMinSatoshis && satoshi < state.lnRecommendedSatoshis {
                    return .lnRecommend
                } else if satoshi >= state.lnRecommendedSatoshis && satoshi <= state.lnMaxSatoshis {
                    return .lnShowFunding
                }
            }
            return .valid
        case .reverseSwap:
            if satoshi < state.reverseSwapLimits?.0 ?? 0 || satoshi > state.reverseSwapLimits?.1 ?? 0 {
                return .invalidReverseSwap
            } else {
                return .valid
            }
        }
    }
    var isConfirmEnabled: Bool {
        if state.satoshi == 0 {
            return false
        } else {
            return fieldState == .valid || fieldState == .lnRecommend || fieldState == .lnShowFunding
        }
    }
    var showBackup: Bool {
       return BackupHelper.shared.needsBackup(walletId: mainAccount.id) && BackupHelper.shared.isDismissed(walletId: mainAccount.id, position: .receive) == false
    }
}
