import Foundation
import GreenlightSDK
import LiquidWalletKit

public class GreenlightSdk {
    private var nodeRpc: Node?
    private let logListener: LogListener
    private let nodeEventListener: NodeEventListener

    init(logListener: LogListener, nodeEventListener: NodeEventListener) {
        self.logListener = logListener
        self.nodeEventListener = nodeEventListener
        try? GreenlightSDK.setLogger(level: .info, listener: logListener)
    }

    func disconnect() {
        try? nodeRpc?.stop()
    }

    func nodeInfo() async throws -> GetInfoResponse {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        return try nodeRpc.getInfo()
    }

    func nodeState() async throws -> NodeState {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        return try nodeRpc.nodeState()
    }

    func nodeEventStream() throws -> NodeEventStream {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        return try nodeRpc.streamNodeEvents()
    }

    public func getLightningInvoice(from bolt11: String) throws -> LightningInvoice {
        let res = try LiquidWalletKit.Payment(s: bolt11)
        switch res.kind() {
        case .lightningInvoice:
            guard let invoice = res.lightningInvoice() else {
                throw GreenlightSDK.Error.Other("Invalid bolt11")
            }
            return LightningInvoice(
                bolt11: bolt11,
                amountSatoshi: invoice.amountMilliSatoshis()?.satoshi,
                timestamp: invoice.timestamp(),
                expiry: invoice.expiryTime(),
                paymentHash: invoice.paymentHash(),
                description: invoice.description)
        default:
            throw GreenlightSDK.Error.Other("Invalid bolt11")
        }
    }

    public func createInvoice(
        satoshi: UInt64,
        description: String
    ) async throws -> LightningReceivePayment {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        let milliseconds = Int64(Date().timeIntervalSince1970 * 1000)
        let response = try nodeRpc.receive(
            label: "inv-\(milliseconds)",
            description: description,
            amountMsat: satoshi.milliSatoshi)
        return LightningReceivePayment(
            invoice: try getLightningInvoice(from: response.bolt11),
            openingFeeSatoshi: response.openingFeeMsat.satoshi)
    }

    static func greenlightKeys() throws -> AppGreenlightCredentials {
        guard let cert = Bundle.main.greenlightDeviceCert,
              let key = Bundle.main.greenlightDeviceKey  else {
            throw GreenlightSDK.Error.Other("No developer cert provided")
        }
        return AppGreenlightCredentials(deviceKey: key, deviceCert: cert)
    }

    func connectNode(credentials: Data, mnemonic: String, greenlightKeys: AppGreenlightCredentials) async throws {
        let config = Config().withDeveloperCert(cert: greenlightKeys.cert)
        self.nodeRpc = try NodeBuilder(config: config)
            .withEventListener(listener: nodeEventListener)
            .connect(credentials: credentials, mnemonic: mnemonic)
    }

    func registerOrRecover(mnemonic: String, greenlightKeys: AppGreenlightCredentials) async throws {
        let config = Config().withDeveloperCert(cert: greenlightKeys.cert)
        self.nodeRpc = try NodeBuilder(config: config)
            .withEventListener(listener: nodeEventListener)
            .registerOrRecover(mnemonic: mnemonic, inviteCode: nil)
    }

    func recover(mnemonic: String, greenlightKeys: AppGreenlightCredentials) async throws {
        let config = Config().withDeveloperCert(cert: greenlightKeys.cert)
        self.nodeRpc = try NodeBuilder(config: config)
            .withEventListener(listener: nodeEventListener)
            .recover(mnemonic: mnemonic)
    }

    func register(mnemonic: String, greenlightKeys: AppGreenlightCredentials) async throws {
        let config = Config().withDeveloperCert(cert: greenlightKeys.cert)
        self.nodeRpc = try NodeBuilder(config: config)
            .withEventListener(listener: nodeEventListener)
            .register(mnemonic: mnemonic, inviteCode: nil)
    }

    public func credentials() async throws -> Data {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        return try nodeRpc.credentials()
    }

    public func listFunds() async throws -> ListFundsResponse {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        return try nodeRpc.listFunds()
    }

    public func listInvoices(label: String?, invstring: String?, paymentHash: Data?, offerId: String?) async throws -> ListInvoicesResponse {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        return try nodeRpc.listInvoices(label: label, invstring: invstring, paymentHash: paymentHash, offerId: offerId, index: nil, start: nil, limit: nil)
    }

    public func listPayments() async throws -> [GreenlightSDK.Payment] {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        let request = ListPaymentsRequest(filters: nil, fromTimestamp: nil, toTimestamp: nil, includeFailures: false, offset: nil, limit: nil)
        return try nodeRpc.listPayments(req: request)
    }

    public func send(bolt11: String, satoshi: UInt64?) async throws -> SendResponse {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        return try nodeRpc.send(invoice: bolt11, amountMsat: satoshi?.milliSatoshi)
    }

    public func onchainSend(destination: String, amountSats: UInt64) async throws -> OnchainSendResult {
        // GL SDK accepts "all" or a sat-denominated amount string
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        let amountOrAll = "\(amountSats)sat"
        let response = try nodeRpc.onchainSend(destination: destination, amountOrAll: amountOrAll)
        return OnchainSendResult(txid: response.txid)
    }

    public func redeemAllOnchainFunds(destination: String) async throws -> OnchainSendResult {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        let response = try nodeRpc.onchainSend(destination: destination, amountOrAll: "all")
        return OnchainSendResult(txid: response.txid)
    }

    public func onchainReceive() async throws -> OnchainReceiveResponse {
        guard let nodeRpc else { throw GreenlightSDK.Error.NoSuchNode("") }
        return try nodeRpc.onchainReceive()
    }
}
