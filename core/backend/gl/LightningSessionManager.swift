core/backend/gl/LightningSessionManager.swiftimport Foundation
import GreenlightSDK
import greenaddress
import lightning
import LiquidWalletKit
import hw

public final class LightningSessionManager {

    var sdk: LightningSdk?
    var xpubHashId: String?
    var streamTask: Task<Void, Never>?
    let network: GdkNetwork
    var connected: Bool = false
    public var logged: Bool = false
    weak var newNotificationDelegate: NewNotificationDelegate?

    public init(network: GdkNetwork, newNotificationDelegate: NewNotificationDelegate? = nil) {
        self.network = network
        self.newNotificationDelegate = newNotificationDelegate
    }

    func setNotificationDelegate(_ delegate: NewNotificationDelegate) {
        self.newNotificationDelegate = delegate
    }

    public static func workingDir(xpub: String) throws -> URL {
        let path = "/gl-sdk/\(xpub)/0"
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.appGroup) {
            return appGroupURL.appending(path: path)
        }
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appending(path: path)
    }

    public func loginUser(params: GreenlightMnemonicAndCredentials, workingDir: String, isForceConnectAllowed: Bool) async throws -> LightningCredentials? {
        guard let greenlightKeys = LightningSdk.CREDENTIALS else {
            throw GreenlightSDK.Error.Other("No greenlight keys found")
        }
        let sdk = LightningSdk(
            workingDir: workingDir,
            greenlightKeys: greenlightKeys,
            logListener: self,
            nodeEventListener: self
        )
        do {
            // connect to greenlight and restore if available
            try await sdk.connect(mnemonicAndCredentials: params, isRestore:  params.credentials == nil)
        } catch {
            // fallback to normal connect
            if isForceConnectAllowed {
                try await sdk.connect(mnemonicAndCredentials: params, isRestore: false)
            } else {
                throw error
            }
        }
        self.sdk = sdk
        logged = true
        connected = true
        // store node credentials
        let nodeCredentials = try await sdk.getNodeCredentials(
            mnemonic: params.mnemonic
        )
        return LightningCredentials(credentials: nodeCredentials)
    }

    public func createInvoice(satoshi: UInt64, description: String) async throws -> LightningReceivePayment {
        guard let sdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        return try await sdk.createInvoice(satoshi: satoshi, description: description)
    }

    public func isPaidInvoice(paymentHash: Data) async throws -> Bool {
        guard let sdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        return try await sdk.isPaidInvoice(paymentHash: paymentHash)
    }

    public func connect() async {
    }
    public func disconnect() async {
        sdk?.stop()
        sdk = nil
        connected = false
        logged = false
        streamTask?.cancel()
    }
    deinit {
        sdk?.stop()
        streamTask?.cancel()
    }

    public func getBalance(subaccount: UInt32, numConfs: Int) async throws -> [String: Int64] {
        let msats = try await sdk?.balance()
        let balance = [AssetInfo.lightningId: Int64(msats?.satoshi ?? 0)]
        return balance
    }

    public func subaccount(_ pointer: UInt32) async throws -> Account {
        return Account(
            gdkName: "",
            pointer: 0,
            receivingId: "",
            type: .lightning,
            hidden: false,
            networkInjected: NetworkId.lightningMainnet.gdkNetwork
        )
    }

    public func subaccounts(_ refresh: Bool = false) async throws -> [Account] {
        let subaccount = try await subaccount(0)
        return [subaccount]
    }

    public func transactions(_ params: GetTransactionsParams) async throws -> Transactions {
        guard let sdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        if params.first > 0 {
            return Transactions(list: [])
        }
        let subaccount = try await self.subaccount(params.subaccount)
        let list = try await sdk.getPayments()
            .map { Transaction.from(payment: $0, account: subaccount) }
        return Transactions(list: list)
    }

    public func transactions(subaccount: UInt32, first: Int = 0, count: Int = 30) async throws -> Transactions {
        let params = GetTransactionsParams(
            subaccount: subaccount,
            first: first,
            count: count
        )
        return try await transactions(params)
    }

    public func updateNodeInfoState() async throws -> NodeState? {
        try await sdk?.updateNodeInfoState()
        return sdk?.nodeState
    }

    public func nodeState() -> NodeState? {
        return sdk?.nodeState
    }

    public func createTransaction(tx: Transaction) async throws -> Transaction {
        guard let addressee = tx.addressees.first else {
            throw GreenlightSDK.Error.Other("Invalid invoice")
        }
        let bolt11 = addressee.address
        let payment = try LiquidWalletKit.Payment(s: bolt11)
        let lightningInvoice = payment.lightningInvoice()
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        let isExpired = (lightningInvoice?.expiryTime() ?? 0) + (lightningInvoice?.timestamp() ?? 0) <= currentTimestamp
        if isExpired {
            throw TransactionError.invalid(localizedDescription: "id_invoice_expired")
        }
        let amount = lightningInvoice?.amountMilliSatoshis()?.satoshi ?? UInt64(addressee.satoshi ?? 0)
        if let maxPayable = nodeState()?.maxPayableMsat.satoshi {
            if amount > maxPayable {
                throw TransactionError.invalid(localizedDescription: "id_insufficient_funds", maxPayable: maxPayable)
            }

        } else {
            let balance = try await getBalance(subaccount: 0, numConfs: 0)
            if amount > balance.first?.value ?? 0 {
                throw TransactionError.invalid(localizedDescription: "id_insufficient_funds")
            }
        }
        return tx
    }

    public func signTransaction(tx: Transaction) async throws -> Transaction {
        return tx
    }
    public func sendTransaction(tx: Transaction) async throws -> SendTransactionSuccess {
        guard let sdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        guard let addressee = tx.addressees.first else {
            throw GreenlightSDK.Error.Other("Invalid invoice")
        }
        let bolt11 = addressee.address
        let satoshi = addressee.satoshi
        let res = try await sdk.sendPayment(bolt11: bolt11, satoshi: satoshi)
        return SendTransactionSuccess(paymentId: res.preimage)
    }

    public func redeemAllOnchainFunds(destination: String) async throws -> String {
        guard let sdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        let res = try await sdk.redeemAllOnchainFunds(destination: destination)
        return res.txid
    }
    public func getReceiveAddress(subaccount: UInt32) async throws -> Address {
        guard let sdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        let res = try await sdk.onchainReceive()
        return Address(address: res.bech32)
    }
    public func registerNotification(fcmToken: String, xpubHashId: String) async throws {
        let nodeId = nodeState()?.id
        try await NotificationDeviceManager.shared.registerDevice(
            walletHashedId: xpubHashId,
            fcmToken: fcmToken,
            nodeId: nodeId
        )
    }
}
extension Transaction {
    static public func from(payment: GreenlightSDK.Payment, account: Account) -> Transaction {
        var tx = Transaction([:])
        tx.setup(account: account)
        let amount = Int64(payment.amountMsat) * (payment.paymentType == .received ? 1 : -1)
        tx.type = payment.paymentType == .received ? .incoming : .outgoing
        tx.memo = payment.description
        tx.fee = payment.feeMsat.satoshi
        tx.createdAtTs = Int64(payment.paymentTime * 1_000_000)
        tx.amounts = [AssetInfo.lightningId: amount.satoshi]
        tx.blockHeight = 0
        tx.paymentPreimage = payment.preimage
        tx.invoice = payment.bolt11
        tx.memo = payment.description
        tx.destinationPubkey = payment.destination
        return tx
    }
}

extension LightningSessionManager: GreenlightSDK.NodeEventListener {
    public func onEvent(event: GreenlightSDK.NodeEvent) {
        switch event {
        case .invoicePaid(let details):
            lightningLogger
                .info(
                    "Invoice paid \(details.paymentHash, privacy: .public) of \(details.amountMsat.satoshi, privacy: .public), updating node info"
                )
            Task {
                _ = try? await updateNodeInfoState()
                newNotificationDelegate?
                    .didReceive(
                        event: .invoicePaid(details),
                        networkId: network.networkId
                    )
            }
        }
    }
}
extension LightningSessionManager: GreenlightSDK.LogListener {
    public func onLog(entry: GreenlightSDK.LogEntry) {
        switch entry.level {
        case .debug:
            lightningLogger.debug("\(entry.message, privacy: .public)")
        case .info:
            lightningLogger.info("\(entry.message, privacy: .public)")
        case .warn:
            lightningLogger.warning("\(entry.message, privacy: .public)")
        case .error:
            lightningLogger.error("\(entry.message, privacy: .public)")
        case .trace:
            lightningLogger.trace("\(entry.message, privacy: .public)")
        }
    }
}
