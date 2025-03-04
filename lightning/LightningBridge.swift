import Foundation
import BreezSDK

public typealias Long = UInt64

public class LightningBridge {

    let testnet: Bool
    public var appGreenlightCredentials: AppGreenlightCredentials?
    public var breezSdk: BlockingBreezServices?
    var eventListener: EventListener
    public var workingDir: URL
    private var network: Network { testnet ? .testnet : .bitcoin }
    private var environment: EnvironmentType { testnet ? .staging : .production }

    public var nodeInfo: NodeState?
    public var lspInformation: LspInformation?

    static var CREDENTIALS: GreenlightCredentials? {
        if let cert = Bundle.main.greenlightDeviceCert,
           let key = Bundle.main.greenlightDeviceKey {
            return GreenlightCredentials(developerKey: [UInt8](key), developerCert: [UInt8](cert))
        }
        return nil
    }

    public init(testnet: Bool,
                workingDir: URL,
                eventListener: EventListener,
                logStreamListener: LogStream?) {
        self.testnet = testnet
        self.eventListener = eventListener
        self.workingDir = workingDir
        if let logStreamListener = logStreamListener {
            try? setLogStream(logStream: logStreamListener)
        }
    }

    private func createConfig(_ partnerCredentials: GreenlightCredentials?) -> Config {
        let greenlightConfig = GreenlightNodeConfig(partnerCredentials: partnerCredentials, inviteCode: nil)
        let nodeConfig = NodeConfig.greenlight(config: greenlightConfig)
        var config = defaultConfig(envType: environment,
                                   apiKey: Bundle.main.breezApiKey ?? "",
                                   nodeConfig: nodeConfig)
        config.workingDir = workingDir.path
        try? FileManager.default.createDirectory(atPath: workingDir.path, withIntermediateDirectories: true)
        return config
    }

    public func connectToGreenlight(mnemonic: String, checkCredentials: Bool) async throws {
        let partnerCredentials = checkCredentials ? nil : LightningBridge.CREDENTIALS
        if breezSdk != nil {
            return
        }
        let connectRequest = ConnectRequest(
            config: createConfig(partnerCredentials),
            seed: try mnemonicToSeed(phrase: mnemonic),
            restoreOnly: checkCredentials)
        breezSdk = try connect(
            req: connectRequest,
            listener: eventListener)
        if breezSdk == nil {
            throw BreezSDK.SdkError.Generic(message: "id_connection_failed")
        }
        if let credentials = LightningBridge.CREDENTIALS {
            appGreenlightCredentials = AppGreenlightCredentials(gc: credentials)
        }
        _ = updateNodeInfo()
    }

    public func stop() throws {
        try breezSdk?.disconnect()
        breezSdk = nil
    }

    public func updateLspInformation() -> LspInformation? {
        if let id = try? breezSdk?.lspId() {
            lspInformation = try? breezSdk?.fetchLspInfo(lspId: id)
            return lspInformation
        }
        return nil
    }

    public func updateNodeInfo() -> NodeState? {
        nodeInfo = try? breezSdk?.nodeInfo()
        print ("NodeInfo: \(nodeInfo.debugDescription)")
        return nodeInfo
    }

    public func balance() -> UInt64? {
        return updateNodeInfo()?.channelsBalanceSatoshi
    }

    public func parseBolt11(bolt11: String) -> LnInvoice? {
        print ("Parse invoice: \(bolt11)")
        if bolt11.isEmpty { return nil }
        do {
            return try parseInvoice(invoice: bolt11)
        } catch {
            print ("Parse invoice: \(error.localizedDescription)"); return nil
        }
    }

    public func parseBoltOrLNUrl(input: String?) -> InputType? {
        guard let input = input else { return nil }
        do {
            return try parseInput(s: input)
        } catch {
            print (error.localizedDescription)
            if !input.starts(with: "lightning:") {
                return try? parseInput(s: "lightning:\(input)")
            }
        }
        return nil
    }

    public func getListPayments() throws -> [Payment] {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        return try breezSdk.listPayments(req: ListPaymentsRequest())
    }

    public func createInvoice(satoshi: Long, description: String, openingFeeParams: OpeningFeeParams? = nil) throws -> ReceivePaymentResponse? {
        try breezSdk?.receivePayment(req: ReceivePaymentRequest(amountMsat: satoshi * 1000, description: description, openingFeeParams: openingFeeParams))
    }
    public func openChannelFee(satoshi: Long) throws -> OpenChannelFeeResponse? {
        try? breezSdk?.openChannelFee(req: OpenChannelFeeRequest(amountMsat: satoshi * 1000))
    }

    public func refund(swapAddress: String, toAddress: String, satPerVbyte: UInt32?) async throws -> RefundResponse {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        var satPerVbyte = satPerVbyte.map {UInt64($0)}
        if satPerVbyte == nil {
            satPerVbyte = await recommendedFees()?.economyFee
        }
        return try breezSdk.refund(req: RefundRequest(swapAddress: swapAddress, toAddress: toAddress, satPerVbyte: UInt32(satPerVbyte ?? 0)))
    }

    public func swapProgress() throws -> SwapInfo? {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        return try breezSdk.inProgressSwap()
    }

    public func listReverseSwapProgress() throws -> [ReverseSwapInfo] {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        return try breezSdk.inProgressOnchainPayments().filter { $0.status == .initial || $0.status == .inProgress }
    }

    public func listRefundables() throws -> [SwapInfo] {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        return try breezSdk.listRefundables()
    }

    public func receiveOnchain(request: ReceiveOnchainRequest = ReceiveOnchainRequest()) throws -> SwapInfo? {
        return try breezSdk?.receiveOnchain(req: request)
    }

    public func recommendedFees() async -> RecommendedFees? {
        return try? breezSdk?.recommendedFees()
    }

    public func sendPayment(bolt11: String, satoshi: UInt64? = nil, useTrampoline: Bool) throws -> SendPaymentResponse? {
        return try breezSdk?.sendPayment(req: SendPaymentRequest(bolt11: bolt11, useTrampoline: useTrampoline, amountMsat: satoshi?.milliSatoshi))
    }

    public func payLnUrl(requestData: LnUrlPayRequestData, amount: Long, comment: String, useTrampoline: Bool) throws -> LnUrlPayResult? {
        return try breezSdk?.payLnurl(req: LnUrlPayRequest(data: requestData, amountMsat: amount.milliSatoshi, useTrampoline: useTrampoline, comment: comment))
    }

    public func authLnUrl(requestData: LnUrlAuthRequestData) throws -> LnUrlCallbackStatus? {
        return try breezSdk?.lnurlAuth(reqData: requestData)
    }

    public func withdrawLnurl(requestData: LnUrlWithdrawRequestData, amount: Long, description: String?) throws -> LnUrlWithdrawResult? {
        return try breezSdk?.withdrawLnurl(request: LnUrlWithdrawRequest(data: requestData, amountMsat: amount.milliSatoshi, description: description))
    }

    public func listLisps() -> [LspInformation]? {
        return try? breezSdk?.listLsps()
    }

    public func connectLsp(id: String) {
        try? breezSdk?.connectLsp(lspId: id)
    }

    public func lspId() -> String? {
        return try? breezSdk?.lspId()
    }

    public func fetchLspInfo(id: String) -> LspInformation? {
        return try? breezSdk?.fetchLspInfo(lspId: id)
    }

    public func closeLspChannels() throws {
        try breezSdk?.closeLspChannels()
        _ = updateNodeInfo()
    }

    public func sweep(toAddress: String, satPerVbyte: UInt32?) async throws -> RedeemOnchainFundsResponse? {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        var satPerVbyte = satPerVbyte.map {UInt64($0)}
        if satPerVbyte == nil {
            satPerVbyte = await recommendedFees()?.economyFee
        }
        let res = try breezSdk.redeemOnchainFunds(req: RedeemOnchainFundsRequest(toAddress: toAddress, satPerVbyte: UInt32(satPerVbyte ?? 0)))
        _ = updateNodeInfo()
        return res
    }

    public func maxReverseSwapAmount() async -> UInt64? {
        return try? breezSdk?.onchainPaymentLimits().maxPayableSat
    }

    public func sendAllOnChain(toAddress: String, satPerVbyte: UInt64?) async throws -> PayOnchainResponse {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        let maxAmount = try breezSdk.onchainPaymentLimits().maxPayableSat
        return try await sendOnChain(toAddress: toAddress, sendAmountSat: maxAmount, satPerVbyte: satPerVbyte)
    }

    public func sendOnChain(toAddress: String, sendAmountSat: UInt64, satPerVbyte: UInt64?) async throws -> PayOnchainResponse {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        let prepareResponse = try await prepareSendOnChain(toAddress: toAddress, sendAmountSat: sendAmountSat, satPerVbyte: satPerVbyte)
        let response = try breezSdk.payOnchain(req: PayOnchainRequest(recipientAddress: toAddress, prepareRes: prepareResponse))
        return response
    }

    public func serviceHealthCheck() -> ServiceHealthCheckResponse? {
        try? BreezSDK.serviceHealthCheck(apiKey: Bundle.main.breezApiKey ?? "")
    }

    public func reportIssue(paymentHash: String) {
        let report = ReportIssueRequest.paymentFailure(data: ReportPaymentFailureDetails(paymentHash: paymentHash, comment: nil))
        try? breezSdk?.reportIssue(req: report)
    }

    public func prepareRefund(swapAddress: String, toAddress: String, satPerVbyte: UInt32?) async throws -> PrepareRefundResponse? {
        try breezSdk?.prepareRefund(
            req: PrepareRefundRequest(
                swapAddress: swapAddress,
                toAddress: toAddress,
                satPerVbyte: satPerVbyte ?? UInt32(breezSdk?.recommendedFees().economyFee ?? 0)
            )
        )
    }

    public func prepareSweep(toAddress: String, satPerVbyte: UInt32?) async throws -> PrepareRedeemOnchainFundsResponse? {
        try breezSdk?.prepareRedeemOnchainFunds(
            req: PrepareRedeemOnchainFundsRequest(
                toAddress: toAddress,
                satPerVbyte: satPerVbyte ?? UInt32(breezSdk?.recommendedFees().economyFee ?? 0)
            )
        )
    }
    public func prepareSendAllOnChain(toAddress: String, satPerVbyte: UInt64?) async throws -> PrepareOnchainPaymentResponse {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        let currentLimits = try breezSdk.onchainPaymentLimits()
        return try await prepareSendOnChain(toAddress: toAddress, sendAmountSat: currentLimits.maxPayableSat, satPerVbyte: satPerVbyte)
    }
    
    public func prepareSendOnChain(toAddress: String, sendAmountSat: UInt64, satPerVbyte: UInt64?) async throws -> PrepareOnchainPaymentResponse {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        let currentLimits = try breezSdk.onchainPaymentLimits()
        if sendAmountSat > min(currentLimits.maxSat, currentLimits.maxPayableSat) {
            throw BreezSDK.SdkError.Generic(message: "Amount exceed current limits")
        } else if sendAmountSat < currentLimits.minSat {
            throw BreezSDK.SdkError.Generic(message: "Amount too low < \(currentLimits.minSat)")
        }
        let currentFees = try breezSdk.fetchReverseSwapFees(req: ReverseSwapFeesRequest(sendAmountSat: sendAmountSat))
        let feeRate = await recommendedFees()?.economyFee
        let satPerVbyte = satPerVbyte ?? feeRate ?? 0
        if sendAmountSat < currentFees.min {
            throw BreezSDK.SdkError.Generic(message: "Amount too low < \(currentFees.min)")
        }
        let prepareRequest = PrepareOnchainPaymentRequest(amountSat: sendAmountSat, amountType: .send, claimTxFeerate: UInt32(satPerVbyte) )
        let prepareResponse = try breezSdk.prepareOnchainPayment(req: prepareRequest)
        return prepareResponse
    }

    public func setCloseToAddress(closeToAddress: String) async throws {
        print("Setting closeToAddress")
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        try breezSdk.configureNode(req: ConfigureNodeRequest(closeToAddress: closeToAddress))
    }

    public func rescanSwaps() async throws {
        try breezSdk?.rescanSwaps()
    }
}
