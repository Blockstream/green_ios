import Foundation
import GreenlightSDK

public class LightningSdk {

    private let workingDir: String
    private let greenlightKeys: AppGreenlightCredentials
    private var greenlightSdk: GreenlightSdk?
    private var nodeCredentials: Data?
    public var nodeInfo: GetInfoResponse?
    public var nodeState: NodeState?
    public var logListener: LogListener
    public var nodeEventListener: NodeEventListener

    public static var CREDENTIALS: AppGreenlightCredentials? {
        if let cert = Bundle.main.greenlightDeviceCert,
           let key = Bundle.main.greenlightDeviceKey {
            return AppGreenlightCredentials(deviceKey: key, deviceCert: cert)
        }
        return nil
    }

    public init(
        workingDir: String,
        greenlightKeys: AppGreenlightCredentials,
        logListener: LogListener,
        nodeEventListener: NodeEventListener
    ) {
        self.workingDir = workingDir
        self.greenlightKeys = greenlightKeys
        self.logListener = logListener
        self.nodeEventListener = nodeEventListener
    }

    public func connect(
        mnemonicAndCredentials: GreenlightMnemonicAndCredentials,
        isRestore: Bool = false
    ) async throws {
        if greenlightSdk != nil {
            return
        }
        let greenlightSdk = GreenlightSdk(
            logListener: logListener,
            nodeEventListener: nodeEventListener
        )

        if let credentials = mnemonicAndCredentials.credentials {
            try await greenlightSdk
                .connectNode(
                    credentials: credentials,
                    mnemonic: mnemonicAndCredentials.mnemonic,
                    greenlightKeys: greenlightKeys)
        } else if !isRestore {
            try await greenlightSdk
                .registerOrRecover(
                    mnemonic: mnemonicAndCredentials.mnemonic,
                    greenlightKeys: greenlightKeys)
        } else {
            try await greenlightSdk
                .recover(
                    mnemonic: mnemonicAndCredentials.mnemonic,
                    greenlightKeys: greenlightKeys)
        }
        self.greenlightSdk = greenlightSdk
        self.nodeCredentials = try await greenlightSdk.credentials()
        try await updateNodeInfoState()
    }

    public func stop() {
        greenlightSdk?.disconnect()
        greenlightSdk = nil
    }

    public func nodeStream() -> NodeEventStream? {
        try? greenlightSdk?.nodeEventStream()
    }

    public func getNodeCredentials(mnemonic: String) async throws -> Data {
        guard let greenlightSdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        return try await greenlightSdk.credentials()
    }

    public func updateNodeInfoState() async throws {
        guard let greenlightSdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        self.nodeInfo = try await greenlightSdk.nodeInfo()
        self.nodeState = try await greenlightSdk.nodeState()
    }

    public func createInvoice(satoshi: UInt64, description: String) async throws -> LightningReceivePayment {
        guard let greenlightSdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        return try await greenlightSdk.createInvoice(satoshi: satoshi, description: description)
    }
    public func balance() async throws -> UInt64 {
        guard let greenlightSdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        let nodeState = try await greenlightSdk.nodeState()
        self.nodeState = nodeState
        return nodeState.totalBalanceMsat
    }
    public func getPaidInvoices() async throws -> [LightningInvoice] {
        guard let greenlightSdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        let res = try await greenlightSdk.listInvoices(
            label: nil,
            invstring: nil,
            paymentHash: nil,
            offerId: nil
        )
        return res.invoices
            .filter { $0.status == .paid }
            .map { LightningInvoice.from(invoice: $0) }
    }

    public func isPaidInvoice(paymentHash: Data) async throws -> Bool {
        return try await greenlightSdk?.listInvoices(
            label: nil,
            invstring: nil,
            paymentHash: paymentHash,
            offerId: nil)
        .invoices.filter({ $0.status == .paid }).count ?? 0 > 0
    }

    public func getPayments() async throws -> [Payment] {
        guard let greenlightSdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        return try await greenlightSdk.listPayments()
            .filter { $0.status == .complete }
    }
    public func sendPayment(bolt11: String, satoshi: Int64?) async throws -> SendResult {
        guard let greenlightSdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        let satoshi = satoshi.map { UInt64($0) }
        let res = try await greenlightSdk.send(bolt11: bolt11, satoshi: satoshi)
        return SendResult(
            status: res.status,
            preimage: res.preimage,
            amountMsat: res.amountMsat,
            feeMsat: res.amountSentMsat - res.amountMsat)
    }

    public func onchainReceive() async throws -> OnchainReceiveResponse {
        guard let greenlightSdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        return try await greenlightSdk.onchainReceive()
    }

    public func redeemAllOnchainFunds(destination: String) async throws -> OnchainSendResult {
        guard let greenlightSdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        return try await greenlightSdk.redeemAllOnchainFunds(destination: destination)
    }
}
