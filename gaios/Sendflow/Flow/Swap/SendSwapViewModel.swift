import Foundation
import UIKit
import AsyncAlgorithms
import LiquidWalletKit
import gdk
import core

@MainActor
final class SendSwapViewModel {

    private var state: SwapPositionState
    private let channel = AsyncChannel<SwapPositionState>()
    private let quoteBuilder: QuoteBuilder?
    private var quoteTask: Task<Void, Never>?
    private var wm: WalletManager

    var selectedPosition: SwapPositionEnum?
    let delegate: SendSwapViewModelDelegate?
    var bitcoinFeeEstimator: FeeEstimator?
    var liquidFeeEstimator: FeeEstimator?
    var gdkTransaction: gdk.Transaction?

    init(wallet: WalletManager, subaccount: WalletItem?, assetId: String?, delegate: SendSwapViewModelDelegate?) {
        self.wm = wallet
        if let boltzSession = wm.lwkSession?.boltzSession {
            self.quoteBuilder = QuoteBuilder(boltzSession: boltzSession)
        } else {
            self.quoteBuilder = nil
        }
        let subaccount = subaccount ?? SendSwapViewModel.getBitcoinSubaccounts().first
        let assetId = assetId ?? AssetInfo.btcId
        let positionFrom = SwapPosition(
            side: .from,
            account: subaccount,
            assetId: assetId,
            amount: nil)
        let positionTo = SwapPosition(
            side: .to,
            account: SendSwapViewModel.getDefaultTo(assetId).0,
            assetId: SendSwapViewModel.getDefaultTo(assetId).1,
            amount: nil)
        let denomination = wallet.prominentSession?.settings?.denomination
        self.state = SwapPositionState(from: positionFrom, to: positionTo, priority: .Medium, denomination: denomination ?? .Sats)
        self.delegate = delegate
        if let bitcoinSession = wm.activeBitcoinSessions.first {
            self.bitcoinFeeEstimator = FeeEstimator(session: bitcoinSession)
        }
        if let liquidSession = wm.activeLiquidSessions.first {
            self.liquidFeeEstimator = FeeEstimator(session: liquidSession)
        }
    }
    func setupEstimators() {
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.bitcoinFeeEstimator?.refreshFeeEstimates()
            await self?.liquidFeeEstimator?.refreshFeeEstimates()
            await MainActor.run { [weak self] in
                let isLiquid = self?.state.from.account?.gdkNetwork.liquid ?? false
                let feeEstimator = isLiquid ? self?.liquidFeeEstimator : self?.bitcoinFeeEstimator
                self?.state.feeRate = feeEstimator?.feeRate(at: self?.state.priority ?? .Medium)
                self?.publish()
            }
        }
    }
    func stateUpdates() -> AsyncChannel<SwapPositionState> {
        channel
    }
    private func publish() {
        let currentState = state
        Task {
            await channel.send(currentState)
        }
    }
    func currentState() -> SwapPositionState {
        state
    }
    static func getDefaultTo(_ assetIdFrom: String) -> (WalletItem?, String) {
        if assetIdFrom == AssetInfo.btcId { // inverted is correct
            return (getLiquidSubaccounts().first, AssetInfo.lbtcId)
        } else if assetIdFrom == AssetInfo.lbtcId { // inverted is correct
            return (getBitcoinSubaccounts().first, AssetInfo.btcId)
        } else {
            return (nil, "")
        }
    }
    static func getBitcoinSubaccounts() -> [WalletItem] {
        WalletManager.current?.bitcoinSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    static func getLiquidSubaccounts() -> [WalletItem] {
        WalletManager.current?.liquidSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    func dialogAccountsModel(_ position: SwapPositionEnum) -> DialogAccountsViewModel {
        self.selectedPosition = position
        let assetId = position == .from ? state.from.assetId : state.to.assetId
        var accounts: [WalletItem] = []
        if assetId == AssetInfo.btcId {
            accounts = SendSwapViewModel.getBitcoinSubaccounts()
        } else if assetId == AssetInfo.lbtcId {
            accounts = SendSwapViewModel.getLiquidSubaccounts()
        }
        return DialogAccountsViewModel(
            title: "id_account_selector".localized,
            hint: "id_choose_which_account_you_want".localized,
            isSelectable: true,
            assetId: assetId,
            accounts: accounts,
            hideBalance: false)
    }
    func shouldShowSelector(_ assetId: String) -> Bool {
        if assetId == AssetInfo.btcId {
            return SendSwapViewModel.getBitcoinSubaccounts().count > 1
        } else if assetId == AssetInfo.lbtcId {
            return SendSwapViewModel.getLiquidSubaccounts().count > 1
        } else {
            return false
        }
    }

    func updatePriority(priority: TransactionPriority, feeRate: UInt64) {
        state.priority = priority
        state.feeRate = feeRate
        publish()
    }

    func updateAccount(account: WalletItem, for position: SwapPositionEnum) {
        switch position {
        case .from:
            state.from.account = account
        case .to:
            state.to.account = account
        }
        let isLiquid = state.from.account?.gdkNetwork.liquid ?? false
        let feeEstimator = isLiquid ? liquidFeeEstimator : bitcoinFeeEstimator
        state.feeRate = feeEstimator?.feeRate(at: state.priority)
        publish()
        scheduleQuote(for: position)
    }
    func updateIsFiat(_ isFiat: Bool) {
        state.isFiat = isFiat
    }
    func updateDenomination(_ denomination: DenominationType) {
        state.denomination = denomination
    }
    func swapPositions(for position: SwapPositionEnum) {
        let tempPosition = state.from
        state.from.assetId = state.to.assetId
        state.from.account = state.to.account
        state.to.assetId = tempPosition.assetId
        state.to.account = tempPosition.account
        let isLiquid = state.from.account?.gdkNetwork.liquid ?? false
        let feeEstimator = isLiquid ? liquidFeeEstimator : bitcoinFeeEstimator
        state.feeRate = feeEstimator?.feeRate(at: state.priority)
        publish()
        scheduleQuote(for: position)
    }
    func updateAmountFromText(_ value: String, for position: SwapPositionEnum) {
        let assetId = position == .from ? state.from.assetId : state.to.assetId
        let balance = state.isFiat ? Balance.fromFiat(value) :
            Balance.fromDenomination(value, assetId: assetId, denomination: state.denomination)
        if let satoshi = balance?.satoshi {
            updateAmount(UInt64(satoshi), for: position)
        } else {
            state.error = nil
            updateAmount(nil, for: position)
        }
    }
    func updateAmount(_ value: UInt64?, for position: SwapPositionEnum) {
        switch position {
        case .from:
            state.from.amount = value
        case .to:
            state.to.amount = value
        }
        publish()
        scheduleQuote(for: position)
    }
    // call the quote on main thread
    func scheduleQuote(for position: SwapPositionEnum) {
        quoteTask?.cancel()
        quoteTask = Task { [weak self] in
            defer { self?.quoteTask = nil }
            do {
                try await Task.sleep(nanoseconds: 250_000_000) // debounce
                guard !Task.isCancelled else { return }
                try await Task.detached(priority: .userInitiated) { [weak self] in
                    guard let self = self, !Task.isCancelled else { return }
                    try await self.performQuote(for: position)
                }.value
            } catch is CancellationError {
                // Graceful exit on cancellation (typing continues)
            } catch {
                self?.state.error = error
                self?.publish()
            }
        }
    }
    // perform the quote on background thread
    func performQuote(for position: SwapPositionEnum) async throws {
        let (fromAmount, fromAsset, toAmount, toAsset) = await MainActor.run {
            (state.from.amount, state.from.swapAsset, state.to.amount, state.to.swapAsset)
        }
        guard let builder = quoteBuilder else {
            throw SendFlowError.serviceUnavailable
        }
        try Task.checkCancellation()
        let res = try await quoteBuilder?.quote(
            amount: position == .from ? fromAmount ?? 0 : toAmount ?? 0,
            mode: position,
            from: fromAsset,
            to: toAsset)
        try Task.checkCancellation()
        try await MainActor.run { [weak self] in
            switch position {
            case .from:
                self?.state.to.amount = fromAmount == nil ? nil : res?.receiveAmount
            case .to:
                self?.state.from.amount = toAmount == nil ? nil : res?.sendAmount
            }
            self?.state.error = nil
            self?.state.networkFee = res?.networkFee
            if let selectedAmount = self?.state.from.amount {
                if let res, selectedAmount < res.min {
                    let minAmount = self?.convertToDenom(satoshi: res.min)
                    let defaultMinAmount = "\(res.min) sats"
                    throw SendFlowError.invalidAmount("Min limit: \(minAmount ?? defaultMinAmount)")
                } else if let res, selectedAmount > res.max {
                    let maxAmount = self?.convertToDenom(satoshi: res.max)
                    let defaultMaxAmount = "\(res.max) sats"
                    throw SendFlowError.invalidAmount("Max limit: \(maxAmount ?? defaultMaxAmount)")
                } else if self?.state.from.account?.btc ?? 0 < selectedAmount {
                    throw SendFlowError.insufficientFunds
                }
            }
            self?.publish()
        }
    }
    func convertToDenom(satoshi: UInt64) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: state.from.assetId)?.toText(state.denomination)
    }
    func feeRateText() -> String? {
        if let feeRate = state.feeRate {
            return String(format: "%.2f sats/vB", Double(feeRate) / 1000.0)
        }
        return nil
    }
    func feeRateTime() -> String? {
        switch state.priority {
        case .Custom:
            return "id_custom".localized
        default:
            let network = state.from.account?.networkType
            return state.priority.time(isLiquid: network?.liquid ?? false)
        }
    }
    func selectAccount(for position: SwapPositionEnum) {
        Task {
            let model = dialogAccountsModel(position)
            delegate?.sendSwapViewModelWillSelectAccount(self, model: model)
        }
    }
    func selectFee() {
        guard let estimator = state.from.assetId == AssetInfo.btcId ? bitcoinFeeEstimator : liquidFeeEstimator else { return }
        // Notify delegate to show the UI picker
        delegate?.sendSwapViewModelWillSelectFee(
            self,
            feeEstimator: estimator,
            priority: state.priority,
            isLiquid: state.from.assetId == AssetInfo.lbtcId
        )
    }
    func dialogInputDenominationViewModel(for position: SwapPositionEnum) -> DialogInputDenominationViewModel? {
        selectedPosition = position
        let list: [DenominationType] = [ .BTC, .MilliBTC, .MicroBTC, .Bits, .Sats]
        let selected = state.denomination
        let network: NetworkSecurityCase = (wm.prominentSession?.gdkNetwork.mainnet ?? true) ? .bitcoinSS : .testnetSS
        return DialogInputDenominationViewModel(denomination: selected,
                                                denominations: list,
                                                network: network,
                                                isFiat: state.isFiat,
                                                balance: nil)
    }
    @MainActor
    func performSwap() async {
        let currentState = self.state
        do {
            let (draft, gdkTx) = try await Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { throw SendFlowError.failedToBuildTransaction }
                return try await self.handleCrossChainSwap(state: currentState)
            }.value
            delegate?.sendSwapViewModelDidTransaction(self, draft: draft, gdkTransaction: gdkTx)
        } catch {
            state.error = error
            publish()
            delegate?.sendSwapViewModelDidFail(self, error: error)
        }
    }
    // build cross chain lockup on background thread
    private nonisolated func handleCrossChainSwap(state: SwapPositionState) async throws -> (TransactionDraft, gdk.Transaction) {
        guard let accountFrom = state.from.account, let accountTo = state.to.account, let amount = state.from.amount else {
            throw SendFlowError.invalidPaymentTarget
        }
        guard let xpub = AccountsRepository.shared.current?.xpubHashId, let lwk = await wm.lwkSession else {
            throw SendFlowError.invalidPaymentTarget
        }
        guard (accountFrom.btc ?? 0) >= amount else {
            throw SendFlowError.insufficientFunds
        }
        let lockupResponse = try await TransactionBuilder.buildCrossChainSwap(from: accountFrom, to: accountTo, amount: amount, lwk: lwk, xpub: xpub)
        let tx = try await TransactionBuilder.buildGdkTransaction(lockupResponse: lockupResponse, subaccount: accountFrom, feeRate: state.feeRate)
        if let error = tx.error {
            throw SendFlowError.gdkError(error)
        }
        let address = try lockupResponse.lockupAddress()
        let paymentTarget: PaymentTarget
        if accountFrom.networkType.liquid {
            paymentTarget = try PaymentTarget.liquidAddress(Address(s: address))
        } else {
            paymentTarget = try PaymentTarget.bitcoinAddress(BitcoinAddress(s: address))
        }
        let draft = TransactionBuilder.buildTransactionDraft(
            paymentTarget: paymentTarget,
            subaccount: accountFrom,
            assetId: state.from.assetId,
            lockupResponse: lockupResponse,
            swapPosition: state)
        return (draft, tx)
    }
}
