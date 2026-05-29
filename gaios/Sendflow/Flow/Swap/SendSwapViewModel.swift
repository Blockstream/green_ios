import Foundation
import UIKit
import AsyncAlgorithms
import LiquidWalletKit
import core

@MainActor
final class SendSwapViewModel {

    private var state: SwapPositionState
    private let channel = AsyncChannel<SwapPositionState>()
    private var quoteBuilder: QuoteBuilder?
    private var quoteTask: Task<Void, Never>?
    private var wm: WalletManager

    var selectedPosition: SwapPositionEnum?
    var lastEditedPosition: SwapPositionEnum = .from
    let delegate: SendSwapViewModelDelegate?
    var bitcoinFeeEstimator: FeeEstimator?
    var liquidFeeEstimator: FeeEstimator?
    var gdkTransaction: core.Transaction?

    // TODO: Make it common, duplicated from the Receive flow
    private var lnMinSatoshis: UInt64 {
        return AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigLnMinSatoshis) as? UInt64 ?? 5_000
    }
    private var lnMaxSatoshis: UInt64 {
        return AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigLnMaxSatoshis) as? UInt64 ?? 400_000
    }
    private var isLimitsFetched = false

    init(
        wm: WalletManager,
        subaccount: Account?,
        assetId: String?,
        initialAsset: SwapAssetType?,
        delegate: SendSwapViewModelDelegate?
    ) {
        self.wm = wm
        let direction = SendSwapViewModel.getSwapDirections(for: initialAsset)
        let defaultAccountAndAssetFrom = SendSwapViewModel.getDefaultAccountAndAsset(for: direction.from)
        let accountFrom = subaccount ?? defaultAccountAndAssetFrom.account
        let assetIdFrom = assetId ?? defaultAccountAndAssetFrom.assetId
        let positionFrom = SwapPosition(
            side: .from,
            type: direction.from,
            account: accountFrom,
            assetId: assetIdFrom,
            amount: nil)
        let defaultAccountAndAssetTo = SendSwapViewModel.getDefaultAccountAndAsset(for: direction.to)
        let positionTo = SwapPosition(
            side: .to,
            type: direction.to,
            account: defaultAccountAndAssetTo.account,
            assetId: defaultAccountAndAssetTo.assetId,
            amount: nil)
        let denomination = wm.prominentSession?.settings?.denomination
        self.state = SwapPositionState(from: positionFrom, to: positionTo, priority: .Medium, denomination: denomination ?? .Sats)
        self.delegate = delegate
        if let networkId = wm.activeBitcoinNetworkIds.first,
           let session = wm.gdkNetworkBackendOrNil(networkId)?.session {
            self.bitcoinFeeEstimator = FeeEstimator(session: session)
        }
        if let networkId = wm.activeLiquidNetworkIds.first,
           let session = wm.gdkNetworkBackendOrNil(networkId)?.session {
            self.liquidFeeEstimator = FeeEstimator(session: session)
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
    func currentState() -> SwapPositionState {
        state
    }
    static func getDefaultAccountAndAsset(for assetType: SwapAssetType) -> (account: Account?, assetId: String) {
        let accounts: [Account]
        let assetId: String
        switch assetType {
        case .bitcoin:
            accounts = getBitcoinSubaccounts()
            assetId = AssetInfo.btcId
        case .lightning:
            accounts = getLightningSubaccounts()
            assetId = AssetInfo.lightningId
        case .liquid:
            accounts = getLiquidSubaccounts()
            assetId = AssetInfo.lbtcId
        }
        
        let funded = accounts.first { account in
            guard let wm = WalletManager.current else { return false }
            return (try? account.isFunded(wm)) ?? false
        }
        return (funded ?? accounts.first, assetId)
    }
    static func getSwapDirections(for assetType: SwapAssetType?) -> (from: SwapAssetType, to: SwapAssetType) {
        switch assetType {
        case .lightning: return (.lightning, .bitcoin)
        case .liquid: return (.liquid, .bitcoin)
        default: return (.bitcoin, .liquid)
        }
    }
    static func getBitcoinSubaccounts() -> [Account] {
        WalletManager.current?.bitcoinSubaccounts.sorted() ?? []
    }
    static func getLiquidSubaccounts() -> [Account] {
        WalletManager.current?.liquidSubaccounts.sorted() ?? []
    }
    static func getLightningSubaccounts() -> [Account] {
        WalletManager.current?.lightningSubaccounts ?? []
    }
    private func publish() {
        let currentState = state
        Task {
            await channel.send(currentState)
        }
    }
    private func checkSwapPairSupport(from: SwapAssetType, to: SwapAssetType) -> Bool {
        let direction = SwapDirection(from: from.swapNetwork, to: to.swapNetwork)
        return from != to &&
            (from == .bitcoin || to == .bitcoin) &&
            SwapAvailability.isCreationEnabled(direction)
    }
    private func formatErrorMessageSatoshi(satoshi: UInt64?) -> String {
        var str = "N/A"
        if let satoshi = satoshi, let balance = Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId) {
            let (value, denom) = balance.toDenom(state.denomination)
            let (fiat, currency) = balance.toFiat()
            str = "\(value) \(denom) (≈ \(fiat) \(currency))"
        }
        return str
    }
    func dialogAccountsModel(_ position: SwapPositionEnum) -> DialogAccountsViewModel {
        self.selectedPosition = position
        let assetId = position == .from ? state.from.assetId : state.to.assetId
        var accounts: [Account] = []
        if assetId == AssetInfo.btcId {
            accounts = SendSwapViewModel.getBitcoinSubaccounts()
        } else if assetId == AssetInfo.lbtcId {
            accounts = SendSwapViewModel.getLiquidSubaccounts()
        }
        return DialogAccountsViewModel(
            title: "Account Selector".localized,
            hint: "id_choose_which_account_you_want".localized,
            isSelectable: true,
            assetId: assetId,
            accounts: accounts,
            hideBalance: false,
            hasCloseButton: true)
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
        scheduleQuote(for: lastEditedPosition)
    }

    func updateAccount(account: Account, for position: SwapPositionEnum) {
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
        state.from.type = state.to.type
        state.from.assetId = state.to.assetId
        state.from.account = state.to.account
        state.to.type = tempPosition.type
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
        let balance = state.isFiat ? Balance.fromFiat(value, assetId: assetId) :
            Balance.from(value, assetId: assetId, denomination: state.denomination)
        if let satoshi = balance?.satoshi {
            updateAmount(UInt64(satoshi), for: position)
        } else {
            state.error = nil
            updateAmount(nil, for: position)
        }
    }
    func updateAmount(_ value: UInt64?, for position: SwapPositionEnum) {
        lastEditedPosition = position
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
        
        let inputAmount = position == .from ? state.from.amount ?? 0 : state.to.amount ?? 0
        if inputAmount == 0 {
            switch position {
            case .from: state.to.amount = nil
            case .to: state.from.amount = nil
            }
            state.networkFee = nil
            state.boltzFee = nil
            state.error = nil
            publish()
            return
        }

        quoteTask = Task { [weak self] in
            defer { self?.quoteTask = nil }
            do {
                try await Task.sleep(nanoseconds: 250_000_000) // debounce
                guard !Task.isCancelled else { return }
                try await self?.performQuote(for: position)
            } catch is CancellationError {
                // Graceful exit on cancellation (typing continues)
            } catch {
                self?.state.error = error
                self?.publish()
            }
        }
    }
    // perform the quote (Implicitly on MainActor, offloads heavy work automatically)
    func performQuote(for position: SwapPositionEnum) async throws {
        let fromAmount = state.from.amount
        let fromAsset = state.from.swapAsset
        let toAmount = state.to.amount
        let toAsset = state.to.swapAsset
        
        guard checkSwapPairSupport(from: state.from.type, to: state.to.type) else {
            throw SwapFlowError.unsupportedSwapPair
        }
        guard let session = await wm.awaitLwkSession()?.boltzSession else {
            throw SwapFlowError.serviceUnavailable
        }
        let builder = quoteBuilder ?? QuoteBuilder(boltzSession: session)
        self.quoteBuilder = builder
        
        let inputAmount = position == .from ? fromAmount ?? 0 : toAmount ?? 0
        try Task.checkCancellation()
        let quote = try await builder.quote(
            amount: inputAmount,
            mode: position,
            from: fromAsset,
            to: toAsset)
        try Task.checkCancellation()
        let calculatedSendAmount = position == .to ? quote?.sendAmount: fromAmount
        let calculatedReceiveAmount = position == .from ? quote?.receiveAmount: toAmount
        
        let currentInputAmount = position == .from ? state.from.amount ?? 0 : state.to.amount ?? 0
        guard currentInputAmount == inputAmount else {
            throw CancellationError()
        }
        
        switch position {
        case .from:
            self.state.to.amount = calculatedReceiveAmount
        case .to:
            self.state.from.amount = calculatedSendAmount
        }
        self.state.networkFee = quote?.networkFee
        self.state.boltzFee = quote?.boltzFee

        if inputAmount > 0 {
            guard let boltzMin = quote?.min, let boltzMax = quote?.max else {
                throw SwapFlowError.serviceUnavailable
            }
            try validateSwapAmount(
                sendAmount: calculatedSendAmount ?? 0,
                receiveAmount: calculatedReceiveAmount ?? 0,
                boltzMin: boltzMin,
                boltzMax: boltzMax
            )
        }
        self.state.error = nil
        self.publish()
    }
    func convertToDenomTrimmed(satoshi: UInt64) -> String? {
        if let (amount, ticker) = Balance.fromSatoshi(satoshi, assetId: state.from.assetId)?.toValue(state.denomination) {
            let trimAmount = amount.removingTrailingZeros()
            return "\(trimAmount) \(ticker)"
        }
        return nil
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
            let network = state.from.account?.networkId
            return "(~\(state.priority.time(isLiquid: network?.liquid ?? false)))"
        }
    }
    func maxDecimals(for position: SwapPositionEnum) -> Int {
        if state.isFiat { return 2 }
        let assetId = position == .from ? state.from.assetId : state.to.assetId
        if AssetInfo.baseIds.contains(assetId) {
            return Int(state.denomination.digits)
        }
        return Int(wm.info(for: assetId).precision ?? 8)
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
        let network: NetworkId = (wm.prominentSession?.gdkNetwork.mainnet ?? true) ? .electrumMainnet : .electrumTestnet
        let balance = {
            switch position {
            case .from:
                Balance.fromSatoshi(state.from.amount ?? 0, assetId: state.from.assetId)
            case .to:
                Balance.fromSatoshi(state.to.amount ?? 0, assetId: state.to.assetId)
            }
        }()
        return DialogInputDenominationViewModel(denomination: selected,
                                                denominations: list,
                                                network: network,
                                                isFiat: state.isFiat,
                                                balance: balance)
    }
    @MainActor
    func performSwap() async {
        let currentState = self.state
        do {
            let (draft, gdkTx) = try await Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { throw SwapFlowError.failedToBuildTransaction }
                return try await self.handleCrossChainSwap(state: currentState)
            }.value
            delegate?.sendSwapViewModelDidTransaction(self, draft: draft, gdkTransaction: gdkTx)
        } catch {
            logger.error("Swap Build Error in handleCrossChainSwap: \(String(describing: error), privacy: .public)")
            state.error = error
            publish()
            delegate?.sendSwapViewModelDidFail(self, error: error)
        }
    }
    // build cross chain lockup on background thread
    private nonisolated func handleCrossChainSwap(state: SwapPositionState) async throws -> (TransactionDraft, core.Transaction) {
        let direction = SwapDirection(from: state.from.type.swapNetwork, to: state.to.type.swapNetwork)
        guard SwapAvailability.isCreationEnabled(direction) else {
            throw SwapFlowError.serviceUnavailable
        }
        guard let accountFrom = state.from.account, let accountTo = state.to.account, let amount = state.from.amount else {
            throw SwapFlowError.invalidPaymentTarget
        }
        guard let xpub = WalletsStorage.shared.current?.xpubHashId, let lwk = await wm.awaitLwkSession() else {
            throw SwapFlowError.invalidPaymentTarget
        }
        if state.route == .lnToBtc {
            let invoiceResponse = try await TransactionBuilder.buildLnToBtcSwap(from: accountFrom, to: accountTo, amount: amount, lwk: lwk, xpub: xpub)
            let bolt11Str = try invoiceResponse.bolt11Invoice().description
            var tx = core.Transaction([:], accountId: accountFrom.id)
            tx.addressees = [Addressee.from(address: bolt11Str, satoshi: Int64(amount), assetId: nil)]
            var draft = TransactionBuilder.buildTransactionDraft(
                paymentTarget: try .lightningInvoice(Bolt11Invoice(s: bolt11Str)),
                subaccount: accountFrom,
                assetId: state.from.assetId,
                swapPosition: state
            )
            draft.invoiceResponse = invoiceResponse
            return (draft, tx)
        } else if state.route == .btcToLn {
            let receiveAmount = state.to.amount ?? amount
            let (preparePayResponse, setupFee) = try await TransactionBuilder.buildBtcToLnSwap(
                from: accountFrom,
                to: accountTo,
                receiveAmount: receiveAmount,
                lwk: lwk,
                xpub: xpub
            )
            let tx = try await TransactionBuilder.buildGdkTransaction(preparePayResponse: preparePayResponse, subaccount: accountFrom, feeRate: state.feeRate)
            if let error = tx.error {
                throw SwapFlowError.gdkError(error)
            }
            let address = try preparePayResponse.lockupAddress()
            var draft = TransactionBuilder.buildTransactionDraft(
                paymentTarget: try .bitcoinAddress(BitcoinAddress(s: address)),
                subaccount: accountFrom,
                assetId: state.from.assetId,
                swapPosition: state
            )
            draft.swapPayResponse = preparePayResponse
            draft.lightningSetupFee = setupFee > 0 ? setupFee : nil
            draft.satoshi = receiveAmount
            return (draft, tx)
        } else {
            let lockupResponse = try await TransactionBuilder.buildCrossChainSwap(from: accountFrom, to: accountTo, amount: amount, lwk: lwk, xpub: xpub)
            let tx = try await TransactionBuilder.buildGdkTransaction(lockupResponse: lockupResponse, subaccount: accountFrom, feeRate: state.feeRate)
            if let error = tx.error {
                throw SwapFlowError.gdkError(error)
            }
            let address = try lockupResponse.lockupAddress()
            let paymentTarget: PaymentTarget
            if accountFrom.networkId.liquid {
                paymentTarget = try PaymentTarget.liquidAddress(LiquidWalletKit.Address(s: address))
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
    func newText(position: SwapPositionEnum, newDenom: DenominationType) -> String {
        var amountStr = ""
        switch position {
        case .from:
            let satoshi = state.from.amount ?? 0
            if satoshi > 0, let (amount, _) = Balance.fromSatoshi(satoshi, assetId: state.from.assetId)?.toValue(newDenom, locale: false) {
                amountStr = amount
            }
        case .to:
            let satoshi = state.to.amount ?? 0
            if satoshi > 0, let (amount, _) = Balance.fromSatoshi(satoshi, assetId: state.to.assetId)?.toValue(newDenom, locale: false) {
                amountStr = amount
            }
        }
        return amountStr
    }
    func newFiatText(position: SwapPositionEnum) -> String {
        var amountStr = ""
        switch position {
        case .from:
            let satoshi = state.from.amount ?? 0
            if satoshi > 0, let (amount, _) = Balance.fromSatoshi(satoshi, assetId: state.from.assetId)?.toFiat(locale: false) {
                amountStr = amount
            }
        case .to:
            let satoshi = state.to.amount ?? 0
            if satoshi > 0, let (amount, _) = Balance.fromSatoshi(satoshi, assetId: state.to.assetId)?.toFiat(locale: false) {
                amountStr = amount
            }
        }
        return amountStr
    }
    func updateAssetType(_ assetType: SwapAssetType, for position: SwapPositionEnum) {
        let oppositeType = position == .from ? state.to.type : state.from.type
        if assetType == oppositeType {
            swapPositions(for: lastEditedPosition)
            return
        }
        let currentType = position == .from ? state.from.type : state.to.type
        if assetType == currentType { return }
        let defaultAccountAndAsset = SendSwapViewModel.getDefaultAccountAndAsset(for: assetType)
        switch position {
        case .from:
            state.from.type = assetType
            state.from.assetId = defaultAccountAndAsset.assetId
            state.from.account = defaultAccountAndAsset.account
            state.from.amount = nil
        case .to:
            state.to.type = assetType
            state.to.assetId = defaultAccountAndAsset.assetId
            state.to.account = defaultAccountAndAsset.account
            state.to.amount = nil
        }

        let isLiquid = state.from.account?.gdkNetwork.liquid ?? false
        let feeEstimator = isLiquid ? liquidFeeEstimator : bitcoinFeeEstimator
        state.feeRate = feeEstimator?.feeRate(at: state.priority)
        publish()
        let oppositePosition = position == .from ? SwapPositionEnum.to : SwapPositionEnum.from
        scheduleQuote(for: oppositePosition)
    }
    private func validateSwapAmount(sendAmount: UInt64, receiveAmount: UInt64, boltzMin: UInt64, boltzMax: UInt64) throws {
        if state.route == .lnToBtc {
            if let maxPayable = state.from.account?.lightningSession?.nodeState()?.maxSendableSatoshi {
                if sendAmount > maxPayable { throw SwapFlowError.insufficientFunds }
            }
        } else if let account = state.from.account, let backend = try? wm.accountBackend(account) {
            let availableBalance = UInt64(backend.assets[state.from.assetId] ?? 0)
            if sendAmount > availableBalance { throw SwapFlowError.insufficientFunds }
        }
        var effectiveMinError: Error? = nil
        var effectiveMaxError: Error? = nil

        var minLimit = boltzMin
        var maxLimit = boltzMax
        var limitAmount = sendAmount
        var errorPosition: SwapPositionEnum = .from

        if state.route == .btcToLn {
            let nodeState = state.to.account?.lightningSession?.nodeState()
            let maxReceivable = nodeState?.maxReceivableSinglePaymentMsat.satoshi ?? 0

            limitAmount = receiveAmount
            errorPosition = .to
            maxLimit = [boltzMax, lnMaxSatoshis, maxReceivable].filter { $0 > 0 }.min() ?? boltzMax
            minLimit = maxReceivable > 0 ? boltzMin : max(boltzMin, lnMinSatoshis)
        }

        if limitAmount > maxLimit {
            effectiveMaxError = SwapFlowError.invalidAmount(msg: String(format: "Maximum is %@".localized, formatErrorMessageSatoshi(satoshi: maxLimit)), position: errorPosition)
        }

        if limitAmount < minLimit {
            effectiveMinError = SwapFlowError.invalidAmount(msg: String(format: "Minimum is %@".localized, formatErrorMessageSatoshi(satoshi: minLimit)), position: errorPosition)
        }

        if let error = effectiveMaxError { throw error }
        if let error = effectiveMinError { throw error }
    }
}
