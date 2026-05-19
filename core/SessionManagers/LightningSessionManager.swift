
import Foundation
import GreenlightSDK
import gdk
import greenaddress
import lightning
import LiquidWalletKit
import hw

public class LightningSessionManager: SessionManager {

    var sdk: LightningSdk?
    var xpubHashId: String?
    var streamTask: Task<Void, Never>?

    init(newNotificationDelegate: NewNotificationDelegate?) {
        super.init(.lightning, newNotificationDelegate: newNotificationDelegate)
    }

    func workingDir(xpubHashId: String) throws -> URL {
        let path = "/gl-sdk/\(xpubHashId)/0"
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

    public override func loginUser(_ params: gdk.Credentials) async throws -> LoginUserResult {
        guard let greenlightKeys = LightningSdk.CREDENTIALS else {
            throw GreenlightSDK.Error.Other("No greenlight keys found")
        }
        guard let walletId = try walletIdentifier(credentials: params) else {
            throw GreenlightSDK.Error.Other("Failed to get walletId")
        }
        let workingDir = try workingDir(xpubHashId: walletId.xpubHashId)
        let sdk = LightningSdk(
            workingDir: workingDir.path,
            greenlightKeys: greenlightKeys,
            logListener: self,
            nodeEventListener: self
        )
        guard let mnemonic = params.mnemonic else {
            throw GreenlightSDK.Error.Other("Invalid mnemonic")
        }
        // get node credentials if available
        let creds = LightningRepository.shared.get(for: walletId.xpubHashId)
        let greenlightCredentials = GreenlightMnemonicAndCredentials(
            mnemonic: mnemonic,
            credentials: creds?.credentials
        )
        do {
            // connect to greenlight and restore if available
            try await sdk
                .connect(
                    mnemonicAndCredentials: greenlightCredentials,
                    isRestore: creds == nil)
        } catch {
            // fallback to normal connect
            try await sdk
                .connect(
                    mnemonicAndCredentials: greenlightCredentials,
                    isRestore: false)
        }
        self.sdk = sdk
        logged = true
        connected = true
        // store node credentials
        let nodeCredentials = try await sdk.getNodeCredentials(mnemonic: mnemonic)
        LightningRepository.shared
            .upsert(
                for: walletId.xpubHashId,
                credentials: LightningCredentials(credentials: nodeCredentials)
            )
        // return login data
        let res = LoginUserResult(xpubHashId: walletId.xpubHashId, walletHashId: walletId.walletHashId)
        self.loginData = res
        return res
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

    public override func connect() async {
    }
    public override func disconnect() async {
        sdk?.stop()
        sdk = nil
        connected = false
        logged = false
        streamTask?.cancel()
    }
    public override func reconnect() async { }
    public override func networkConnect() async { }
    public override func networkDisconnect() async { }
    public override func changeSettings(settings: Settings) async throws -> Settings? {
        return nil
    }

    public override func getBalance(subaccount: UInt32, numConfs: Int) async throws -> [String: Int64] {
        let msats = try await sdk?.balance()
        let balance = [AssetInfo.lightningId: Int64(msats?.satoshi ?? 0)]
        return balance
    }

    public override func subaccount(_ pointer: UInt32) async throws -> WalletItem {
        return WalletItem(name: "", pointer: 0, receivingId: "", type: .lightning, hidden: false, network: NetworkSecurityCase.lightning.network)
    }

    public override func subaccounts(_ refresh: Bool = false) async throws -> [WalletItem] {
        let subaccount = try await subaccount(0)
        return [subaccount]
    }

    public override func transactions(subaccount: UInt32, first: Int = 0, count: Int = 30) async throws -> Transactions {
        guard let sdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        if first > 0 {
            return Transactions(list: [])
        }
        let subaccount = try await self.subaccount(subaccount)
        let list = try await sdk.getPayments()
            .map { Transaction.from(payment: $0, subaccountId: subaccount.id) }
        return Transactions(list: list)
    }

    public override func loginUser(_ params: HWDevice) async throws -> LoginUserResult {
        throw GreenlightSDK.Error.Other("Not supported")
    }

    public func updateNodeInfoState() async throws -> NodeState? {
        try await sdk?.updateNodeInfoState()
        return sdk?.nodeState
    }

    public func nodeState() -> NodeState? {
        return sdk?.nodeState
    }

    public override func createTransaction(tx: gdk.Transaction) async throws -> gdk.Transaction {
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
        } else if amount > tx.subaccount?.btc ?? 0 {
            throw TransactionError.invalid(localizedDescription: "id_insufficient_funds")
        }
        return tx
    }

    public override func signTransaction(tx: gdk.Transaction) async throws -> gdk.Transaction {
        return tx
    }
    public override func sendTransaction(tx: gdk.Transaction) async throws -> SendTransactionSuccess {
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
    public override func getReceiveAddress(subaccount: UInt32) async throws -> gdk.Address {
        guard let sdk else {
            throw GreenlightSDK.Error.Other("Not connected")
        }
        let res = try await sdk.onchainReceive()
        return gdk.Address(address: res.bech32)
    }
}
extension gdk.Transaction {
    static public func from(payment: GreenlightSDK.Payment, subaccountId: String) -> gdk.Transaction {
        var tx = Transaction([:])
        tx.subaccountId = subaccountId
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
                newNotificationDelegate?.didReceive(event: .invoicePaid, networkType: networkType)
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
