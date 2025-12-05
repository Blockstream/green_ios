import Foundation
import LiquidWalletKit
import gdk
import greenaddress
import hw


public struct BoltzReverseSwapInfoLBTC: Codable {
    public let hash: String
    public let rate: Int
    public let limits: BoltzSwapInfoLimits
    public let fees: BoltzReverseSwapInfoFees
}

public struct BoltzSubmarineSwapInfoLBTC: Codable {
    public let hash: String
    public let rate: Int
    public let limits: BoltzSwapInfoLimits
    public let fees: BoltzSwapInfoFees
}

public struct BoltzSwapInfoLimits: Codable {
    public let maximal: Int64
    public let minimal: Int64
}

public struct BoltzReverseSwapInfoFees: Codable {
    public let percentage: Double
    public let minerFees: BoltzSwapInfominerFees
}

public struct BoltzSwapInfoFees: Codable {
    public let percentage: Double
    public let minerFees: Int64
}

public struct BoltzSwapInfominerFees: Codable {
    public let claim: UInt64
    public let lockup: UInt64
}

public enum BoltzSwapTypes: String {
    case Submarine = "submarine"
    case ReverseSubmarine = "reverse"
}



public class LwkSessionManager: SessionManager {

    static let BOLTZ_BIP85_INDEX: UInt32 = 26589
    static let BASE_URL = "https://green-webhooks.blockstream.com/"
    static let DEV_BASE_URL = "https://green-webhooks.dev.blockstream.com/"
    var network = Network.mainnet()
    public var boltzSession: BoltzSession?
    var xpubHashId: String?

    public init(network: Network = Network.mainnet(), boltzSession: BoltzSession? = nil, xpubHashId: String? = nil) {
        super.init(NetworkSecurityCase.lwkMainnet)
        self.network = network
        self.boltzSession = boltzSession
        self.xpubHashId = xpubHashId
        self.session = GDKSession()
    }

    public override func reconnect() async { }
    public override func networkConnect() async { }
    public override func networkDisconnect() async { }
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
        throw GaError.GenericError("Not supported")
    }

    public override func loginUser(_ params: Credentials) async throws -> LoginUserResult {
        guard let secret = params.mnemonic else {
            throw GaError.GenericError("Invalid mnemonic")
        }
        let client = try network.defaultElectrumClient()
        let builder = BoltzSessionBuilder(
            network: network,
            client: AnyClient.fromElectrum(client: client),
            timeout: 30_000,
            mnemonic: try Mnemonic(s: secret),
            logging: self,
            polling: true,
            timeoutAdvance: 10_000,
            randomPreimages: true
        )
        boltzSession = try BoltzSession.fromBuilder(builder: builder)
        logged = true
        guard let walletHash = try walletIdentifier(credentials: params) else {
            throw GaError.GenericError("Invalid wallet hash")
        }
        return LoginUserResult(xpubHashId: walletHash.xpubHashId, walletHashId: walletHash.walletHashId)
    }

    func webhookBaseUrl() -> String {
        Bundle.main.dev ? LwkSessionManager.DEV_BASE_URL : LwkSessionManager.BASE_URL
    }

    nonisolated public func invoice(amount: UInt64, description: String?, claimAddress: LiquidWalletKit.Address) async throws -> InvoiceResponse {
        guard let xpubHashId = xpubHashId else {
            throw LwkError.Generic(msg: "No xpub defined")
        }
        guard let boltzSession = boltzSession else {
            throw LwkError.Generic(msg: "No lwk session")
        }
        let invoiceStatuses = ["transaction.mempool", "transaction.confirmed", "invoice.settled"]
        let webhook = WebHook(url: "\(webhookBaseUrl())/webhook/boltz/\(xpubHashId)", status: invoiceStatuses)
        let res = try boltzSession.invoice(
            amount: amount,
            description: description,
            claimAddress: claimAddress,
            webhook: webhook)

        let data = try res.serialize()
        let swapId = try res.swapId()
        let bolt11 = try res.bolt11Invoice().description
        _ = try await BoltzController.shared.create(id: swapId, data: data, isPending: true, xpubHashId: xpubHashId, invoice: bolt11)
        return res
    }

    nonisolated public func preparePay(invoice: String, refundAddress: LiquidWalletKit.Address) async throws -> PreparePayResponse {
        guard let xpubHashId = xpubHashId else {
            throw LwkError.Generic(msg: "No xpub defined")
        }
        guard let boltzSession = boltzSession else {
            throw LwkError.Generic(msg: "No lwk session")
        }
        let bolt11 = try Bolt11Invoice(s: invoice)
        // We want to know if we need to create a refund. TODO: reassess once mainchain to liquid chain swaps are introduced
        let preparePayStatuses = ["invoice.paid", "swap.expired", "invoice.failedToPay", "transaction.lockupFailed"]
        let webhook = WebHook(url: "\(webhookBaseUrl())/webhook/boltz/\(xpubHashId)", status: preparePayStatuses)
        let res = try boltzSession.preparePay(
            lightningPayment: LightningPayment.fromBolt11Invoice(invoice: bolt11),
            refundAddress: refundAddress,
            webhook: webhook)
        let data = try res.serialize()
        let swapId = try res.swapId()
        _ = try await BoltzController.shared.create(id: swapId, data: data, isPending: true, xpubHashId: xpubHashId, invoice: invoice)
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

    nonisolated public func restorePreparePay(data: String) async throws -> PreparePayResponse? {
        try boltzSession?.restorePreparePay(data: data)
    }

    nonisolated public func handlePay(pay: PreparePayResponse) async throws -> PaymentState {
        let swapId = try pay.swapId()
        let persistentId = try? await BoltzController.shared.fetchID(byId: swapId)
        guard let peristentId = persistentId else {
            logger.error("LWK \(swapId, privacy: .public) not found")
            throw GaError.GenericError("Swap not found")
        }
        var state = PaymentState.continue
        repeat {
            do {
                state = try pay.advance()
                switch state {
                case .continue:
                    let data = try pay.serialize()
                    _ = try await BoltzController.shared.update(with: peristentId, newData: data, newIsPending: true)
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                case .success:
                    logger.info("LWK \(swapId, privacy: .public) completed successfully!")
                    _ = try await BoltzController.shared.update(with: peristentId, newIsPending: false)
                case .failed:
                    logger.info("LWK \(swapId, privacy: .public) failed!")
                    _ = try await BoltzController.shared.delete(with: peristentId)
                }
            } catch {
                logger.error("LWK \(swapId, privacy: .public) error: \(error.localizedDescription, privacy: .public)")
                switch error as? LwkError {
                case .NoBoltzUpdate:
                    let swap = try? await BoltzController.shared.get(with: peristentId)
                    if let swap = swap {
                        if swap.isPending {
                            try await Task.sleep(nanoseconds: 1_000_000_000)
                        } else {
                            state = PaymentState.success
                        }
                    } else {
                        state = PaymentState.failed
                    }
                default:
                    throw error
                }
            }
        } while state == PaymentState.continue
        return state
    }

    nonisolated public func handleInvoice(invoice: InvoiceResponse) async throws -> PaymentState {
        let swapId = try invoice.swapId()
        let persistentId = try? await BoltzController.shared.fetchID(byId: swapId)
        guard let persistentId = persistentId else {
            logger.error("LWK \(swapId, privacy: .public) not found")
            throw GaError.GenericError("Swap not found")
        }
        var state = PaymentState.continue
        repeat {
            do {
                state = try invoice.advance()
                switch state {
                case .continue:
                    let data = try invoice.serialize()
                    logger.info("LWK \(swapId, privacy: .public) updated with \(data[0..<64])")
                    _ = try await BoltzController.shared.update(with: persistentId, newData: data, newIsPending: true)
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                case .success:
                    logger.info("LWK \(swapId, privacy: .public) completed successfully!")
                    _ = try await BoltzController.shared.update(with: persistentId, newIsPending: false)
                case .failed:
                    logger.info("LWK \(swapId, privacy: .public) failed!")
                    _ = try await BoltzController.shared.delete(with: persistentId)
                }
            } catch {
                logger.error("LWK \(swapId, privacy: .public) error: \(error.localizedDescription, privacy: .public)")
                switch error as? LwkError {
                case .NoBoltzUpdate:
                    let swap = try? await BoltzController.shared.get(with: persistentId)
                    if let swap = swap {
                        if swap.isPending {
                            try await Task.sleep(nanoseconds: 1_000_000_000)
                        } else {
                            state = PaymentState.success
                        }
                    } else {
                        state = PaymentState.failed
                    }
                default:
                    throw error
                }
            }
        } while state == PaymentState.continue
        return state
    }

    nonisolated public func fetchReverseSwapsInfo() async throws -> BoltzReverseSwapInfoLBTC? {
        guard let jsonString = try boltzSession?.fetchSwapsInfo() else {
            logger.error("LWK fetchReverseSwapsInfo failed")
            throw LwkError.Generic(msg: "Fails to fetch swaps info")
        }
        logger.info("LWK fetchReverseSwapsInfo \(jsonString)")
        let data = Data(jsonString.utf8)
        let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let reverse = dict?["reverse"] as? [String: Any]
        let btc = reverse?["BTC"] as? [String: Any]
        let lbtc = btc?["L-BTC"] as? [String: Any]
        return try JSONDecoder().decode(BoltzReverseSwapInfoLBTC.self, from: JSONSerialization.data(withJSONObject: lbtc ?? [:]))
    }

    nonisolated public func fetchSubmarineSwapsInfo() async throws -> BoltzSubmarineSwapInfoLBTC? {
        guard let jsonString = try boltzSession?.fetchSwapsInfo() else {
            logger.error("LWK fetchSubmarineSwapsInfo failed")
            throw LwkError.Generic(msg: "Fails to fetch swaps info")
        }
        logger.info("LWK fetchSubmarineSwapsInfo \(jsonString)")
        let data = Data(jsonString.utf8)
        let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let submarine = dict?["submarine"] as? [String: Any]
        let lbtc = submarine?["L-BTC"] as? [String: Any]
        let btc = lbtc?["BTC"] as? [String: Any]
        return BoltzSubmarineSwapInfoLBTC.from(btc ?? [:]) as? BoltzSubmarineSwapInfoLBTC
    }
}

extension LwkSessionManager: Logging {
    public func log(level: LiquidWalletKit.LogLevel, message: String) {
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warn:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
}
