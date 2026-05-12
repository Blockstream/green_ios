import Foundation
import LiquidWalletKit
import gdk
import greenaddress
import hw
public class LwkSessionManager: SessionManager {

    static public let BOLTZ_BIP85_INDEX: UInt32 = 26589
    static let BASE_URL = "https://green-webhooks.blockstream.com/"
    static let DEV_BASE_URL = "https://green-webhooks.dev.blockstream.com/"
    var network = Network.mainnet()
    public var boltzSession: BoltzSession?
    var xpubHashId: String?
    private var client: AnyClient?

    public init(
        network: Network = Network.mainnet(),
        boltzSession: BoltzSession? = nil,
        xpubHashId: String? = nil,
        client: AnyClient? = nil,
        newNotificationDelegate: NewNotificationDelegate?) {
        super.init(NetworkSecurityCase.lwkMainnet, newNotificationDelegate: newNotificationDelegate)
        self.network = network
        self.boltzSession = boltzSession
        self.xpubHashId = xpubHashId
        self.client = client
        self.session = GDKSession()
    }
    public override func connect() async { }
    public override func disconnect() async {
        boltzSession = nil
    }
    public override func reconnect() async { }
    public override func networkConnect() async { }
    public override func networkDisconnect() async { }
    public override func changeSettings(settings: Settings) async throws -> Settings? {
        return nil
    }
    public override func subaccount(_ pointer: UInt32) async throws -> WalletItem? {
        return nil
    }
    public override func subaccounts(_ refresh: Bool = false) async throws -> [WalletItem] {
        return []
    }
    public override func transactions(subaccount: UInt32, first: Int = 0, count: Int = 30) async throws -> Transactions {
        return Transactions(list: [])
    }
    public override func loginUser(_ params: HWDevice) async throws -> LoginUserResult {
        throw LwkError.Generic(msg: "Not supported")
    }

    public override func loginUser(_ params: Credentials) async throws -> LoginUserResult {
        guard let secret = params.mnemonic else {
            throw LwkError.Generic(msg: "Invalid mnemonic")
        }
        if client == nil {
            client = try getClient()
        }
        boltzSession = try createBoltzSession(
            client: client!,
            mnemonic: try Mnemonic(s: secret))
        logged = true
        guard let walletHash = try walletIdentifier(credentials: params) else {
            throw LwkError.Generic(msg: "Invalid wallet hash")
        }
        return LoginUserResult(xpubHashId: walletHash.xpubHashId, walletHashId: walletHash.walletHashId)
    }
    
    func getClient() throws -> AnyClient {
        do {
            let client = try network.defaultElectrumClient()
            return AnyClient.fromElectrum(client: client)
        } catch {
            let esploraClient = try network.defaultEsploraClient()
            return AnyClient.fromEsplora(client: esploraClient)
        }
    }
    
    func createBoltzSession(client: AnyClient, mnemonic: Mnemonic) throws -> BoltzSession {
        let bitcoinElectrumUrl = network.isMainnet()
        ? "ssl://bitcoin-mainnet.blockstream.info:50002"
        : "ssl://bitcoin-testnet.blockstream.info:60002"
        let builder = BoltzSessionBuilder(
            network: network,
            client: client,
            timeout: 30_000,
            mnemonic: mnemonic,
            logging: self,
            polling: true,
            timeoutAdvance: 10_000,
            referralId: "blockstream",
            bitcoinElectrumClientUrl: bitcoinElectrumUrl,
            randomPreimages: true
        )
        return try BoltzSession.fromBuilder(builder: builder)
    }

    func webhookBaseUrl() -> String {
        Bundle.main.dev ? LwkSessionManager.DEV_BASE_URL : LwkSessionManager.BASE_URL
    }

    func webhook(status: [String]?) throws -> WebHook {
        guard let xpubHashId = xpubHashId else {
            throw LwkError.Generic(msg: "No xpub defined")
        }
        return WebHook(url: "\(webhookBaseUrl())/webhook/boltz/\(xpubHashId)", status: status ?? [])
    }

    // Reverse Submarine Swaps (Lightning -> Chain)
    nonisolated public func invoice(amount: UInt64, description: String?, claimAddress: LiquidWalletKit.Address) async throws -> InvoiceResponse {
        guard let boltzSession = boltzSession else {
            throw LwkError.Generic(msg: "No lwk session")
        }
        let invoiceStatuses = ["transaction.mempool", "transaction.confirmed", "invoice.settled"]
        let res = try boltzSession.invoice(
            amount: amount,
            description: description,
            claimAddress: claimAddress,
            webhook: try webhook(status: invoiceStatuses))
        let bolt11 = try res.bolt11Invoice().description
        _ = try await BoltzController.shared.create(
            id: try res.swapId(),
            data: try res.serialize(),
            isPending: true,
            xpubHashId: xpubHashId,
            invoice: bolt11,
            swapType: .reverseSwap,
            txHash: nil)
        return res
    }

    nonisolated public func preparePay(
        lightningPayment: LightningPayment,
        refundAddress: LiquidWalletKit.Address
    ) async throws -> PreparePayResponse {
        guard let boltzSession = boltzSession else {
            throw LwkError.Generic(msg: "No lwk session")
        }
        let preparePayStatuses = ["invoice.paid", "swap.expired", "invoice.failedToPay", "transaction.lockupFailed"]
        let res = try boltzSession.preparePay(
            lightningPayment: lightningPayment,
            refundAddress: refundAddress,
            webhook: try webhook(status: preparePayStatuses))
        _ = try await BoltzController.shared.create(
            id: try res.swapId(),
            data: try res.serialize(),
            isPending: true,
            xpubHashId: xpubHashId,
            invoice: try lightningPayment.bolt11Invoice()?.description,
            swapType: .submarineSwap,
            txHash: nil)
        return res
    }

    nonisolated public func lbtcToBtc(amount: UInt64, refundAddress: String, claimAddress: String, xpubHashId: String) async throws -> LockupResponse {
        guard let boltzSession = boltzSession else {
            throw LwkError.Generic(msg: "No lwk session")
        }
        //let chainSwapStatuses = ["transaction.confirmed", "transaction.server.confirmed", "transaction.claimed", "transaction.lockupFailed"]
        let res = try boltzSession.lbtcToBtc(
            amount: amount,
            refundAddress: try Address(s: refundAddress),
            claimAddress: try BitcoinAddress(s: claimAddress),
            webhook: try webhook(status: []))
        _ = try await BoltzController.shared.create(
            id: try res.swapId(),
            data: try res.serialize(),
            isPending: true,
            xpubHashId: xpubHashId,
            invoice: nil,
            swapType: .chainSwap,
            txHash: nil)
        return res
    }
    nonisolated public func btcToLbtc(amount: UInt64, refundAddress: String, claimAddress: String, xpubHashId: String) async throws -> LockupResponse {
        guard let boltzSession = boltzSession else {
            throw LwkError.Generic(msg: "No lwk session")
        }
        //let chainSwapStatuses = ["transaction.confirmed", "transaction.server.confirmed", "transaction.claimed", "transaction.lockupFailed"]
        let res = try boltzSession.btcToLbtc(
            amount: amount,
            refundAddress: try BitcoinAddress(s: refundAddress),
            claimAddress: try Address(s: claimAddress),
            webhook: try webhook(status: []))
        _ = try await BoltzController.shared.create(
            id: try res.swapId(),
            data: try res.serialize(),
            isPending: true,
            xpubHashId: xpubHashId,
            invoice: nil,
            swapType: .chainSwap,
            txHash: nil)
        return res
    }
    /*
     nonisolated public func completePay(pay: PreparePayResponse) async throws -> Bool {
     try pay.completePay()
     }
     
     nonisolated public func completePay(invoice: InvoiceResponse) async throws -> Bool {
     try invoice.completePay()
     }*/
    nonisolated public func restoreInvoice(data: String) async throws -> InvoiceResponse? {
        try boltzSession?.restoreInvoice(data: data)
    }

    nonisolated public func restoreLockup(data: String) async throws -> LockupResponse? {
        try boltzSession?.restoreLockup(data: data)
    }

    nonisolated public func restorePreparePay(data: String) async throws -> PreparePayResponse? {
        try boltzSession?.restorePreparePay(data: data)
    }

    nonisolated public func fetchReverseSwapsInfo() async throws -> BoltzReverseSwapInfoLBTC? {
        guard let jsonString = try boltzSession?.fetchSwapsInfo() else {
            lwkLogger.error("fetchReverseSwapsInfo failed")
            throw LwkError.Generic(msg: "Fails to fetch swaps info")
        }
        lwkLogger.info("fetchReverseSwapsInfo \(jsonString)")
        let data = Data(jsonString.utf8)
        let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let reverse = dict?["reverse"] as? [String: Any]
        let btc = reverse?["BTC"] as? [String: Any]
        let lbtc = btc?["L-BTC"] as? [String: Any]
        return try JSONDecoder().decode(BoltzReverseSwapInfoLBTC.self, from: JSONSerialization.data(withJSONObject: lbtc ?? [:]))
    }

    nonisolated public func fetchSubmarineSwapsInfo() async throws -> BoltzSubmarineSwapInfoLBTC? {
        guard let jsonString = try boltzSession?.fetchSwapsInfo() else {
            lwkLogger.error("fetchSubmarineSwapsInfo failed")
            throw LwkError.Generic(msg: "Fails to fetch swaps info")
        }
        lwkLogger.info("fetchSubmarineSwapsInfo \(jsonString)")
        let data = Data(jsonString.utf8)
        let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let submarine = dict?["submarine"] as? [String: Any]
        let lbtc = submarine?["L-BTC"] as? [String: Any]
        let btc = lbtc?["BTC"] as? [String: Any]
        return BoltzSubmarineSwapInfoLBTC.from(btc ?? [:]) as? BoltzSubmarineSwapInfoLBTC
    }

    nonisolated public func restoreSwaps(bitcoinAddress: String, liquidAddress: String, xpubHashId: String) async throws {
        guard let boltzSession = boltzSession else {
            throw LwkError.Generic(msg: "Invalid session")
        }
        let liquidAddress = try Address(s: liquidAddress)
        let list = try boltzSession.swapRestore()
        // Reverse Submarine Swaps: avoid to restore reverse submarine swaps for lack of informations to correctly restore them.
        // Submarine Swaps: restore swaps with lockup transaction and refund liquid address
        lwkLogger.info("Restoring submarine swaps using address \(liquidAddress)")
        let submarineSwaps = try boltzSession.restorableSubmarineSwaps(swapList: list, refundAddress: liquidAddress)
        for submarineSwap in submarineSwaps {
            let pay = try boltzSession.restorePreparePay(data: submarineSwap)
            let swapId = try pay.swapId()
            let data = try pay.serialize()
            lwkLogger.info("Restoring \(swapId)")
            if let swapDbId = try? await BoltzController.shared.fetchID(byId: swapId) {
                try? await BoltzController.shared.update(
                    with: swapDbId,
                    newIsPending: true,
                    newTxHash: try? pay.lockupTxid())
            } else {
                _ = try? await BoltzController.shared.create(
                    id: swapId,
                    data: data,
                    isPending: true,
                    xpubHashId: xpubHashId,
                    invoice: nil,
                    swapType: SwapType.submarineSwap,
                    txHash: try? pay.lockupTxid())
            }
        }
        lwkLogger.info("Restoring swaps using address \(bitcoinAddress)")
        let bitcoinAddress = try BitcoinAddress(s: bitcoinAddress)
        let btcToLbtcSwaps = try boltzSession.restorableBtcToLbtcSwaps(swapList: list, claimAddress: liquidAddress, refundAddress: bitcoinAddress)
        let lbtcToBtcSwaps = try boltzSession.restorableLbtcToBtcSwaps(swapList: list, claimAddress: bitcoinAddress, refundAddress: liquidAddress)
        for swap in btcToLbtcSwaps + lbtcToBtcSwaps {
            let lockup = try boltzSession.restoreLockup(data: swap)
            let swapId = try lockup.swapId()
            let data = try lockup.serialize()
            lwkLogger.info("Restoring \(swapId)")
            if let swapDbId = try? await BoltzController.shared.fetchID(byId: swapId) {
                try? await BoltzController.shared.update(
                    with: swapDbId,
                    newIsPending: true,
                    newTxHash: try? lockup.lockupTxid())
            } else {
                _ = try? await BoltzController.shared.create(
                    id: swapId,
                    data: data,
                    isPending: true,
                    xpubHashId: xpubHashId,
                    invoice: nil,
                    swapType: SwapType.chainSwap,
                    txHash: try? lockup.lockupTxid())
            }
        }
    }
}

extension LwkSessionManager: Logging {
    public func log(level: LiquidWalletKit.LogLevel, message: String) {
        switch level {
        case .debug:
            lwkLogger.debug("\(message, privacy: .public)")
        case .info:
            lwkLogger.info("\(message, privacy: .public)")
        case .warn:
            lwkLogger.warning("\(message, privacy: .public)")
        case .error:
            lwkLogger.error("\(message, privacy: .public)")
        }
    }
}
