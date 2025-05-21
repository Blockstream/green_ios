import Foundation
import BreezSDK
import OSLog
import gdk
import greenaddress
import lightning
import hw

public class LightningSessionManager: SessionManager {

    public var lightBridge: LightningBridge?
    public var accountId: String?
    public var isRestoredNode: Bool?

    public var chainNetwork: NetworkSecurityCase { gdkNetwork.mainnet ? .bitcoinSS : .testnetSS }
    public var workingDir: URL? { lightBridge?.workingDir }
    public var nodeState: NodeState? { lightBridge?.nodeInfo }
    public var lspInfo: LspInformation? { lightBridge?.lspInformation }

    public var logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "Lightning"
    )

    public override func connect() async throws {
        paused = false
    }

    public override func disconnect() async throws {
        logged = false
        connected = false
        paused = false
        do {
            try lightBridge?.stop()
        } catch {
            logger.error("lightning disconnect error \(error.localizedDescription)")
            throw error
        }
        lightBridge = nil
    }

    public override func networkConnect() async {
        paused = false
    }

    public override func networkDisconnect() async {
        paused = true
    }

    func workingDir(walletHashId: String) -> URL {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.appGroup)
        let path = "/breezSdk/\(walletHashId)/0"
        if #available(iOS 16.0, *) {
            return containerURL!.appending(path: path)
        } else {
            return containerURL!.appendingPathComponent(path)
        }
    }

    private func initLightningBridge(_ params: Credentials, eventListener: EventListener) -> LightningBridge {
        guard let walletIdentifier = try? walletIdentifier(credentials: params) else {
            fatalError("Invalid wallet identifier")
        }
        return LightningBridge(testnet: !gdkNetwork.mainnet,
                               workingDir: workingDir(walletHashId: walletIdentifier.walletHashId),
                               eventListener: eventListener,
                               logStreamListener: self)
    }

    private func connectToGreenlight(credentials: Credentials, checkCredentials: Bool = false) async throws {
        guard let mnemonic = credentials.mnemonic else {
            fatalError("Invalid mnemonic")
        }
        AnalyticsManager.shared.loginLightningStart()
        try await lightBridge?.connectToGreenlight(mnemonic: mnemonic, checkCredentials: checkCredentials)
        AnalyticsManager.shared.loginLightningStop()
        connected = true
    }

    public func smartLogin(credentials: Credentials, listener: EventListener) async throws {
        lightBridge = initLightningBridge(credentials, eventListener: listener)
        try await connectToGreenlight(credentials: credentials, checkCredentials: false)
        logged = true
    }

    public override func loginUser(credentials: Credentials? = nil, hw: HWDevice? = nil) async throws -> LoginUserResult {
        guard let params = credentials else { throw LoginError.connectionFailed() }
        let walletId = try walletIdentifier(credentials: params)
        let walletHashId = walletId!.walletHashId
        let res = LoginUserResult(xpubHashId: walletId?.xpubHashId ?? "", walletHashId: walletId?.walletHashId ?? "")
        let restore = LightningRepository.shared.get(for: walletHashId) == nil
        lightBridge = initLightningBridge(params, eventListener: self)
        do {
            logger.info("lightning loginUser \(credentials.toDict()?.description ?? "") \(restore)")
            try await connectToGreenlight(credentials: params, checkCredentials: restore)
            isRestoredNode = restore
        } catch {
            do {
                logger.info("lightning loginUser \(credentials.toDict()?.description ?? "")")
                try await connectToGreenlight(credentials: params)
            } catch {
                logger.info("lightning loginUser failed \(error.description())")
                throw error
            }
        }
        if let greenlightCredentials = lightBridge?.appGreenlightCredentials {
            LightningRepository.shared.upsert(for: walletHashId, credentials: greenlightCredentials)
        }
        logged = true
        loginData = res
        return res
    }

    public func registerNotification(token: String, xpubHashId: String) async throws {
        if let notificationService = Bundle.main.notificationService {
            logger.info("register notification token \(token, privacy: .public) with xpubHashId \(xpubHashId, privacy: .public) at \(notificationService, privacy: .public)")
            try lightBridge?.breezSdk?.registerWebhook(webhookUrl: "\(notificationService)/api/v1/notify?platform=\("ios")&token=\(token)&app_data=\(xpubHashId)")
        }
    }

    public func unregisterNotification(token: String, xpubHashId: String) {
        if let notificationService = Bundle.main.notificationService {
            logger.info("unregister notification token \(token, privacy: .public) with xpubHashId \(xpubHashId, privacy: .public) at \(notificationService, privacy: .public)")
            try? lightBridge?.breezSdk?.unregisterWebhook(webhookUrl: "\(notificationService)/api/v1/notify?platform=\("ios")&token=\(token)&app_data=\(xpubHashId)")
        }
    }

    public override func register(credentials: Credentials? = nil, hw: HWDevice? = nil) async throws {
    }

    public override func walletIdentifier(credentials: Credentials) throws -> WalletIdentifier? {
        let res = try self.session?.getWalletIdentifier(
            net_params: GdkSettings.read()?.toNetworkParams(chainNetwork.network).toDict() ?? [:],
            details: credentials.toDict() ?? [:])
        return WalletIdentifier.from(res ?? [:]) as? WalletIdentifier
    }

    public override func walletIdentifier(masterXpub: String) -> WalletIdentifier? {
        let details = ["master_xpub": masterXpub]
        let res = try? self.session?.getWalletIdentifier(
            net_params: GdkSettings.read()?.toNetworkParams(chainNetwork.network).toDict() ?? [:],
            details: details)
        return WalletIdentifier.from(res ?? [:]) as? WalletIdentifier
    }

    public override func existDatadir(walletHashId: String) -> Bool {
        LightningRepository.shared.get(for: walletHashId) != nil
    }

    public override func removeDatadir(walletHashId: String) async {
        try? FileManager.default.removeItem(at: workingDir(walletHashId: walletHashId))
        LightningRepository.shared.remove(for: walletHashId)
    }

    public override func getBalance(subaccount: UInt32, numConfs: Int) async throws -> [String: Int64] {
        let sats = lightBridge?.balance()
        let balance = [AssetInfo.lightningId: Int64(sats ?? 0)]
        return balance
    }

    public override func subaccount(_ pointer: UInt32) async throws -> WalletItem {
        return WalletItem(name: "", pointer: 0, receivingId: "", type: .lightning, hidden: false, network: NetworkSecurityCase.lightning.network)
    }

    public override func subaccounts(_ refresh: Bool = false) async throws -> [WalletItem] {
        let subaccount = try await subaccount(0)
        return [subaccount]
    }

    public override func signTransaction(tx: Transaction) async throws -> Transaction {
        return tx
    }

    public override func sendTransaction(tx: Transaction) async throws -> SendTransactionSuccess {
        let addressee = tx.addressees.first
        let invoiceOrLnUrl = addressee?.address
        let satoshi = tx.anyAmouts ? UInt64(addressee?.satoshi ?? 0) : nil
        let comment = tx.memo ?? ""
        switch lightBridge?.parseBoltOrLNUrl(input: invoiceOrLnUrl) {
        case .bolt11(let invoice):
            // Check for expiration
            print ("Expire in \(invoice.expiry)")
            if invoice.isExpired {
                throw TransactionError.invalid(localizedDescription: "id_invoice_expired")
            }
            do {
                if let res = try lightBridge?.sendPayment(bolt11: invoice.bolt11, satoshi: satoshi, useTrampoline: true) {
                    return SendTransactionSuccess.create(from: res.payment)
                }
            } catch {
                let msg = error.description() ?? "id_operation_failure"
                throw TransactionError.failure(localizedDescription: msg, paymentHash: invoice.paymentHash)
            }
        case .lnUrlPay(let data, let bip353Address):
            let res = try lightBridge?.payLnUrl(requestData: data, amount: satoshi ?? 0, comment: comment, useTrampoline: true)
            switch res {
            case .endpointSuccess(let data):
                print("payLnUrl success: \(data)")
                return SendTransactionSuccess.create(from: data)
            case .endpointError(let data):
                print("payLnUrl endpointError: \(data.reason)")
                throw TransactionError.invalid(localizedDescription: data.reason.errorMessage ?? data.reason)
            case .payError(let data):
                print("payLnUrl payError: \(data.reason)")
                throw TransactionError.failure(localizedDescription: data.reason.errorMessage ?? data.reason, paymentHash: data.paymentHash)
            case .none:
                break
            }
        default:
            break
        }
        throw TransactionError.invalid(localizedDescription: "id_error")
    }

    public func generateLightningError(
        account: WalletItem,
        satoshi: UInt64?,
        min: UInt64? = nil,
        max: UInt64? = nil
    ) -> String? {
        let balance = account.btc ?? 0
        guard let satoshi = satoshi, satoshi > 0 else {
            return "id_invalid_amount"
        }
        if let min = min, satoshi < min {
            return "Amount must be at least \(min)"
        }
        if satoshi > balance {
            return "id_insufficient_funds"
        }
        if let max = max, satoshi > max {
            return "Amount must be at most \(max)"
        }
        return nil
    }

    public override func createTransaction(tx: Transaction) async throws -> Transaction {
        let address = tx.addressees.first?.address ?? ""
        let userInputSatoshi = tx.addressees.first?.satoshi ?? 0
        switch lightBridge?.parseBoltOrLNUrl(input: address) {
        case .bolt11(let invoice):
            // Check for expiration
            print ("Expire in \(invoice.expiry)")
            let sendableSatoshi = invoice.sendableSatoshi(userSatoshi: UInt64(abs(userInputSatoshi))) ?? 0
            var tx = tx
            var addressee = Addressee.fromLnInvoice(invoice, fallbackAmount: sendableSatoshi)
            addressee.satoshi = abs(addressee.satoshi ?? 0)
            tx.error = ""
            tx.addressees = [addressee]
            tx.amounts = ["btc": Int64(sendableSatoshi)]
            tx.transactionOutputs = [TransactionInputOutput.fromLnInvoice(invoice, fallbackAmount: Int64(sendableSatoshi))]
            if let description = invoice.description {
                tx.memo = description
            }
            if invoice.isExpired {
                tx.error = "id_invoice_expired"
            } else if let subaccount = tx.subaccount,
               let error = generateLightningError(account: subaccount, satoshi: sendableSatoshi) {
                tx.error = error
            }
            return tx
        case .lnUrlPay(let requestData, let bip353Address):
            let sendableSatoshi = requestData.sendableSatoshi(userSatoshi: UInt64(userInputSatoshi)) ?? 0
            var tx = tx
            var addressee = Addressee.fromRequestData(requestData, input: address, satoshi: sendableSatoshi)
            addressee.satoshi = abs(addressee.satoshi ?? 0)
            tx.error = ""
            tx.addressees = [addressee]
            tx.amounts = ["btc": Int64(sendableSatoshi)]
            tx.transactionOutputs = [TransactionInputOutput.fromLnUrlPay(requestData, input: address, satoshi: Int64(sendableSatoshi))]
            if let subaccount = tx.subaccount,
               let error = generateLightningError(account: subaccount, satoshi: sendableSatoshi, min: requestData.minSendableSatoshi, max: requestData.maxSendableSatoshi) {
                tx.error = error
            }
            return tx
        default:
            return tx
        }
    }

    public override func discovery(refresh: Bool, updateHidden: Bool) async throws {
    }

    public func createInvoice(satoshi: UInt64, description: String) async throws -> ReceivePaymentResponse? {
        try lightBridge?.createInvoice(satoshi: satoshi, description: description)
    }

    public override func parseTxInput(_ input: String, satoshi: Int64?, assetId: String?, network: NetworkSecurityCase?) async throws -> ValidateAddresseesResult {
        guard let inputType = lightBridge?.parseBoltOrLNUrl(input: input) else {
            throw GaError.GenericError()
        }
        switch inputType {
        case .bitcoinAddress:
            // let addr = Addressee.from(address: address.address, satoshi: Int64(address.amountSat ?? 0), assetId: nil)
            // return ValidateAddresseesResult(isValid: true, errors: [], addressees: [addr])
            return ValidateAddresseesResult(isValid: false, errors: ["id_invalid_address"], addressees: [])
        case .bolt11(let invoice):
            if invoice.isExpired {
                return ValidateAddresseesResult(isValid: true, errors: ["id_invoice_expired"], addressees: [])
            }
            if let satoshi = invoice.amountSatoshi {
                let subaccount = try await subaccount(0)
                subaccount.satoshi = try await getBalance(subaccount: 0, numConfs: 0)
                if let error = generateLightningError(account: subaccount, satoshi: satoshi) {
                    return ValidateAddresseesResult(isValid: true, errors: [error], addressees: [])
                }
            }
            let addr = Addressee.fromLnInvoice(invoice, fallbackAmount: 0)
            return ValidateAddresseesResult(isValid: true, errors: [], addressees: [addr])
        case .lnUrlPay(let data, let bip353Address):
            let addr = Addressee.fromRequestData(data, input: input, satoshi: nil)
            return ValidateAddresseesResult(isValid: true, errors: [], addressees: [addr])
        case .lnUrlAuth, .lnUrlWithdraw:
            let addr = Addressee.from(address: input, satoshi: nil, assetId: nil)
            return ValidateAddresseesResult(isValid: true, errors: [], addressees: [addr])
        case .nodeId, .url, .lnUrlError:
            return ValidateAddresseesResult(isValid: false, errors: ["Unsupported"], addressees: [])
        }
    }

    public override func getReceiveAddress(subaccount: UInt32) async throws -> Address {
        guard let addr = try lightBridge?.receiveOnchain() else {
            throw GaError.GenericError()
        }
        return Address.from(swapInfo: addr)
    }

    public override func transactions(subaccount: UInt32, first: Int = 0, count: Int = 30) async throws -> Transactions {
        // check valid breez api
        guard let lb = self.lightBridge else {
            return Transactions(list: [])
        }
        let subaccountId = try await subaccounts().first?.id
        // get list payments
        var txs = try lb.getListPayments().compactMap { Transaction.fromPayment($0, subaccountId: subaccountId) }
        // get list refundables
        txs += try lb.listRefundables().compactMap { Transaction.fromSwapInfo($0, subaccountId: subaccountId, isRefundableSwap: true) }
        // get list reverse swap
        txs += try lb.listReverseSwapProgress().compactMap { Transaction.fromReverseSwapInfo($0, subaccountId: subaccountId, isRefundableSwap: false) }
        // get swap in progress
        if let sp = try lb.swapProgress() {
            txs += [sp].compactMap {
                Transaction.fromSwapInfo($0, subaccountId: subaccountId, isRefundableSwap: false)
            }
        }
        txs = txs.sorted().reversed()
        txs = Array(txs.suffix(from: min(first, txs.count)).prefix(count))
        return Transactions(list: txs)
    }

    public func closeChannels() throws {
        try lightBridge?.closeLspChannels()
    }
}

extension LightningSessionManager: EventListener {
    public func onEvent(e: BreezEvent) {
        logger.info("Breez event \(e.description, privacy: .public)")
        switch e {
        case .synced:
            DispatchQueue.main.async {
                self.post(event: .InvoicePaid)
            }
        case .newBlock(let block):
            blockHeight = block
            DispatchQueue.main.async {
                self.post(event: .Block)
            }
        case .invoicePaid(let data):
            DispatchQueue.main.async {
                self.post(event: .InvoicePaid, object: data)
            }
        case .paymentSucceed:
            DispatchQueue.main.async {
                self.post(event: .PaymentSucceed)
            }
        case .paymentFailed:
            DispatchQueue.main.async {
                self.post(event: .PaymentFailed)
            }
        default:
            break
        }
    }
}

extension LightningSessionManager: LogStream {
    public func log(l: LogEntry) {
        switch l.level.lowercased() {
        case "error", "warning":
            logger.error("\(l.line, privacy: .public)")
        default: break
        }
    }
}
