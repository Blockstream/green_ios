import Foundation
import BreezSDK

public typealias Long = UInt64

public protocol LightningEventListener {
    func onLightningEvent(event: BreezEvent)
}

class LogStreamListener: LogStream {
    func log(l: LogEntry){
      //print("BREEZ: \(l.line)");
    }
}

public class LightningBridge {
    
    let testnet: Bool
    public var appGreenlightCredentials: AppGreenlightCredentials?
    var breezSdk: BlockingBreezServices?
    var eventListener: LightningEventListener
    var workingDir: URL
    private var network: Network { testnet ? .testnet : .bitcoin }
    private var environment: EnvironmentType { testnet ? .staging : .production }
    
    static public var BREEZ_API_KEY: String? {
        let content = Bundle.main.infoDictionary?["BREEZ_API_KEY"] as? String
        // print("BREEZ_API_KEY: \(content)")
        if content == nil { print("BREEZ_API_KEY: UNDEFINED") }
        return content
    }
    static public var GREENLIGHT_DEVICE_CERT: Data? {
        let path = Bundle.main.path(forResource: "green", ofType: "crt") ?? ""
        let content = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        if let content = content?.filter({ !$0.isWhitespace }) {
            // print("GREENLIGHT_DEVICE_CERT: \(content)")
            return Data(base64Encoded: content)
        } else {
            print("GREENLIGHT_DEVICE_CERT: UNDEFINED")
        }
        return nil
    }
    static public var GREENLIGHT_DEVICE_KEY: Data? {
        let path = Bundle.main.path(forResource: "green", ofType: "pem") ?? ""
        let content = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        if let content = content?.filter({ !$0.isWhitespace }) {
            // print("GREENLIGHT_DEVICE_KEY: \(content)")
            return Data(base64Encoded: content)
        } else {
            print("GREENLIGHT_DEVICE_KEY: UNDEFINED")
        }
        return nil
    }
    static var CREDENTIALS: GreenlightCredentials? {
        if let cert = LightningBridge.GREENLIGHT_DEVICE_CERT,
           let key = LightningBridge.GREENLIGHT_DEVICE_KEY {
            return GreenlightCredentials(deviceKey: [UInt8](key), deviceCert: [UInt8](cert))
        }
        return nil
    }
    
    public init(testnet: Bool,
                workingDir: URL,
                eventListener: LightningEventListener) {
        self.testnet = testnet
        self.eventListener = eventListener
        self.workingDir = workingDir
    }
    
    public static func configure() {
        try? setLogStream(logStream: LogStreamListener())
    }

    public func connectToGreenlight(mnemonic: String, checkCredentials: Bool) async throws {
        let partnerCredentials = checkCredentials ? nil : LightningBridge.CREDENTIALS
        try await self.start(mnemonic: mnemonic, partnerCredentials: partnerCredentials)
    }
    
    private func createConfig(_ partnerCredentials: GreenlightCredentials?) -> Config {
        let greenlightConfig = GreenlightNodeConfig(partnerCredentials: partnerCredentials, inviteCode: nil)
        let nodeConfig = NodeConfig.greenlight(config: greenlightConfig)
        var config = defaultConfig(envType: environment,
                                   apiKey: LightningBridge.BREEZ_API_KEY ?? "",
                                   nodeConfig: nodeConfig)
        config.workingDir = workingDir.path
        try? FileManager.default.createDirectory(atPath: workingDir.path, withIntermediateDirectories: true)
        return config
    }
    
    private func start(mnemonic: String, partnerCredentials: GreenlightCredentials?) async throws {
        if breezSdk != nil {
            return
        }
        breezSdk = try connect(
            config: createConfig(partnerCredentials),
            seed: mnemonicToSeed(phrase: mnemonic),
            listener: self)
        if breezSdk == nil {
            throw BreezSDK.SdkError.Generic(message: "id_connection_failed")
        }
        if let credentials = LightningBridge.CREDENTIALS {
            appGreenlightCredentials = AppGreenlightCredentials(gc: credentials)
        }
        _ = updateNodeInfo()
        _ = updateLspInformation()
    }
    
    public func stop() {
        try? breezSdk?.disconnect()
        breezSdk = nil
    }
    
    public func updateLspInformation() -> LspInformation? {
        if let id = try? breezSdk?.lspId() {
            return try? breezSdk?.fetchLspInfo(lspId: id)
        }
        return nil
    }
    
    public func updateNodeInfo() -> NodeState? {
        let res = try? breezSdk?.nodeInfo()
        print ("NodeInfo: \(res.debugDescription)")
        return res
    }
    
    public func balance() -> UInt64? {
        return updateNodeInfo()?.channelsBalanceSatoshi
    }
    
    public func parseBolt11(bolt11: String) -> LnInvoice? {
        print ("Parse invoice: \(bolt11)")
        if bolt11.isEmpty { return nil }
        do { return try parseInvoice(invoice: bolt11) }
        catch { print ("Parse invoice: \(error.localizedDescription)"); return nil }
    }
    
    public func parseBoltOrLNUrl(input: String?) -> InputType? {
        guard let input = input else { return nil }
        return try? parseInput(s: input)
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
        return try breezSdk.refund(req: RefundRequest(swapAddress: swapAddress, toAddress: toAddress, satPerVbyte:  UInt32(satPerVbyte ?? 0)))
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
        return try breezSdk.inProgressReverseSwaps()
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
    
    public func sendPayment(bolt11: String, satoshi: UInt64? = nil) throws -> SendPaymentResponse? {
        return try breezSdk?.sendPayment(req: SendPaymentRequest(bolt11: bolt11, amountMsat: satoshi?.milliSatoshi))
    }
    
    public func payLnUrl(requestData: LnUrlPayRequestData, amount: Long, comment: String) throws -> LnUrlPayResult? {
        return try breezSdk?.payLnurl(req: LnUrlPayRequest(data: requestData, amountMsat: amount.milliSatoshi, comment: comment))
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
        return try? breezSdk?.maxReverseSwapAmount().totalSat
    }

    public func sendAllOnChain(toAddress: String, satPerVbyte: UInt?) async throws -> SendOnchainResponse {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        let maxAmount = try breezSdk.maxReverseSwapAmount()
        return try await sendOnChain(toAddress: toAddress, sendAmountSat: maxAmount.totalSat, satPerVbyte: satPerVbyte)
    }

    public func sendOnChain(toAddress: String, sendAmountSat: UInt64, satPerVbyte: UInt?) async throws -> SendOnchainResponse {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        let currentFees = try breezSdk.fetchReverseSwapFees(req: ReverseSwapFeesRequest(sendAmountSat: sendAmountSat))
        var satPerVbyte = satPerVbyte.map {UInt64($0)}
        if satPerVbyte == nil {
            satPerVbyte = await recommendedFees()?.economyFee
        }
        return try breezSdk.sendOnchain(req: SendOnchainRequest(amountSat: sendAmountSat, onchainRecipientAddress: toAddress, pairHash: currentFees.feesHash, satPerVbyte: UInt32(satPerVbyte ?? 0)))
    }

    public func serviceHealthCheck() -> ServiceHealthCheckResponse? {
        try? breezSdk?.serviceHealthCheck()
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

    public func prepareSendAllOnChain(toAddress: String, satPerVbyte: UInt?) async throws {
        guard let breezSdk = breezSdk else {
            throw BreezSDK.SdkError.Generic(message: "Unitialized breez sdk")
        }
        let sendAmountSat = try breezSdk.maxReverseSwapAmount().totalSat
        let currentFee = try breezSdk.fetchReverseSwapFees(req: ReverseSwapFeesRequest(sendAmountSat: sendAmountSat))
        if sendAmountSat < currentFee.min {
            throw BreezSDK.SdkError.Generic(message: "Amount is too low")
        }
    }
}

extension LightningBridge: EventListener {
    public func onEvent(e: BreezEvent) {
        print ("Breez onEvent: \(e)")
        eventListener.onLightningEvent(event: e)
        switch e {
        case BreezEvent.invoicePaid( _):
            Task { try? breezSdk?.sync() }
            break
        case BreezEvent.paymentSucceed(_):
            break
        default:
            break
        }
    }
}

