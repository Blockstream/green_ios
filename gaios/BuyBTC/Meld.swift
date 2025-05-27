import Foundation
import core
import greenaddress
import gdk

enum MeldTransactionType: String {
    case BUY
    case SELL
}

struct MeldQuoteParams: Codable {
    let destinationCurrencyCode: String
    let countryCode: String
    let sourceAmount: String
    let sourceCurrencyCode: String
    var paymentMethodType: String
}

struct MeldQuoteItem: Codable {
    let transactionType: String
    let exchangeRate: Float
    let customerScore: Float
    let serviceProvider: String
    let destinationAmount: Float
}

extension MeldQuoteItem {
    func btc() -> String? {
        let amount = Int64(destinationAmount * 100_000_000)
        return Balance.fromSatoshi(amount, assetId: "btc")?.toText()
    }
}

struct MeldQuoteResponse: Codable {
    let quotes: [MeldQuoteItem]
    let message: String?
}

struct MeldSessionParams: Codable {
    let serviceProvider: String
    let countryCode: String
    let destinationCurrencyCode: String
    let lockFields: [String]
    let paymentMethodType: String
    // let redirectUrl: String
    let sourceAmount: String
    let sourceCurrencyCode: String
    let walletAddress: String
}

struct MeldWidgetParams: Codable {
    let sessionData: MeldSessionParams
    let sessionType: String
    let externalCustomerId: String
}

struct MeldWidgetResponse: Codable {
    let id: String
    let customerId: String?
    let widgetUrl: String?
    let token: String?
    let message: String?
}

struct MeldTransactionsRequest: Codable {
    let externalCustomerIds: String
    let statuses: String
}

struct MeldTransactionsResponse: Codable {
    let transactions: [MeldTransaction]
    let count: Int
    let remaining: Int
    let totalCount: Int
}

enum MeldTransactionStatus: String, Codable {
    case PENDING_CREATED
    case PENDING
    case PROCESSING
    case AUTHORIZED
    case AUTHORIZATION_EXPIRED
    case SETTLING
    case SETTLED
    case REFUNDED
    case DECLINED
    case CANCELLED
    case FAILED
    case ERROR
    case VOIDED
    case TWO_FA_REQUIRED
    case TWO_FA_PROVIDED
}

public struct MeldServiceProviderDetails: Codable {
    let txnHash: String?
    let type: String
    let status: String
}

public struct MeldTransaction: Codable {
    let key: String
    let id: String
    let status: MeldTransactionStatus
    let serviceProvider: String
    let sourceAmount: Double
    let sourceCurrencyCode: String
    let destinationAmount: Double
    let destinationCurrencyCode: String
    let createdAt: String
    let updatedAt: String
    let countryCode: String
    let externalCustomerId: String
    let fiatAmountInUsd: Double
    let serviceProviderDetails: MeldServiceProviderDetails?
}

public struct MeldEvent: Codable {
    let eventType: String
    let eventId: String
    let timestamp: String
    let accountId: String
    let version: String
    let payload: MeldTransactionPayload
}

public struct MeldTransactionPayload: Codable {
    let accountId: String
    let paymentTransactionId: String
    let customerId: String
    let externalCustomerId: String?
    let externalSessionId: String?
    let paymentTransactionStatus: String
}

extension Transaction {
    public static func fromMeldTransaction(_ transaction: MeldTransaction) -> Transaction {
        var tx = Transaction([:])
        tx.blockHeight = UInt32.max
        tx.canRBF = false
        let dfmatter = DateFormatter()
        dfmatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        let date = dfmatter.date(from: transaction.createdAt)
        tx.createdAtTs = Int64(date?.timeIntervalSince1970  ?? 0) * 1_000_000
        tx.hash = transaction.serviceProviderDetails?.txnHash
        tx.type = .incoming
        tx.amounts = [AssetInfo.btcId: Int64(transaction.destinationAmount * Double(100_000_000))]
        tx.isMeldPayment = true
        return tx
    }
}

struct MeldTokenRegistrationRequest: Codable {
    let externalCustomerId: String
    let fcmToken: String
    let platform: String
}

struct MeldTokenRegistrationResponse: Codable {
}

struct Meld {

    private static let MELD_API_PRODUCTION = "https://ramps.blockstream.com"
    private static let MELD_API_SANDBOX = "https://ramps.sandbox.blockstream.com"
    private static let MELD_NOTIFICATIONS_URL_PRODUCTION = "https://green-webhooks.blockstream.com"
    private static let MELD_NOTIFICATIONS_URL_SANDBOX = "https://green-webhooks.dev.blockstream.com"
    private static let MELD_PREFIX_LABEL = "MELD_FETCH_REQUEST_TRANSACTIONS_FOR_"
    private static let MELD_SANDBOX_LABEL = "MELD_SANBOX"

    static var isSandboxEnvironment: Bool {
        get { UserDefaults(suiteName: Bundle.main.appGroup)?.bool(forKey: Meld.MELD_SANDBOX_LABEL) ?? false }
        set { UserDefaults(suiteName: Bundle.main.appGroup)?.setValue(newValue, forKey: Meld.MELD_SANDBOX_LABEL)}
    }
    var meldApiUrl: String {
        Meld.isSandboxEnvironment ? Meld.MELD_API_SANDBOX : Meld.MELD_API_PRODUCTION
    }
    var notificationUrl: String {
        Meld.isSandboxEnvironment ? Meld.MELD_NOTIFICATIONS_URL_SANDBOX : Meld.MELD_NOTIFICATIONS_URL_PRODUCTION
    }

    func quote(_ params: MeldQuoteParams) async throws -> [MeldQuoteItem] {
        let url = "\(meldApiUrl)/payments/crypto/quote"
        let res: MeldQuoteResponse = try await Meld.call(url: url, method: "POST", params: params)
        if let message = res.message {
            throw GaError.GenericError(message)
        }
        let quotes = res.quotes
        return quotes.sorted { $0.destinationAmount < $1.destinationAmount }
    }

    func widget(_ params: MeldWidgetParams) async throws -> String {
        let url = "\(meldApiUrl)/crypto/session/widget"
        let res: MeldWidgetResponse = try await Meld.call(url: url, method: "POST", params: params)
        if let widgetUrl = res.widgetUrl {
            return widgetUrl
        } else if let message = res.message {
            throw GaError.GenericError(message)
        } else {
            throw GaError.GenericError("Invalid request")
        }
    }

    func transactions(_ params: MeldTransactionsRequest) async throws -> MeldTransactionsResponse {
        let url = "\(meldApiUrl)/payments/transactions"
        return try await Meld.call(url: url, method: "GET", params: params)
    }

    static func call<T: Codable, K: Codable>(url: String, method: String, params: T) async throws -> K {
        switch method {
        case "GET":
            let query = params
                .toDict()?
                .map { (key, value) in
                    "\(key)=\(value)"
                }
            var url = url
            if let query = query {
                url = "\(url)?\(query.joined(separator: "&"))"
            }
            guard let url = URL(string: url) else {
                throw GaError.GenericError("Invalid url")
            }
            logger.info("Meld \(url.description, privacy: .public)")
            let res = try await Meld.call(url: url, method: method, data: nil)
            logger.info("Meld \(String(data: res, encoding: .utf8) ?? "", privacy: .public)")
            return try JSONDecoder().decode(K.self, from: res)
        case "POST":
            guard let url = URL(string: url) else {
                throw GaError.GenericError("Invalid url")
            }
            let data = try params.encoded()
            logger.info("Meld \(url.description, privacy: .public) \(params.toDict()?.description ?? "No params", privacy: .public)")
            let res = try await Meld.call(url: url, method: method, data: data)
            logger.info("Meld \(String(data: res, encoding: .utf8) ?? "", privacy: .public)")
            return try JSONDecoder().decode(K.self, from: res)
        default:
            logger.error("Meld Invalid request")
            throw GaError.GenericError("Invalid request")
        }
    }

    static func call(url: URL, method: String, data: Data?) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpMethod = method
        if method == "POST" {
            request.httpBody = data
        }
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    func getPendingTransactions(xpub: String) async throws -> [Transaction] {
        let statuses = [MeldTransactionStatus.SETTLING].map({$0.rawValue}).joined(separator: ",")
        return try await transactions(MeldTransactionsRequest(externalCustomerIds: xpub, statuses: statuses))
            .transactions
            .map({Transaction.fromMeldTransaction($0)})
    }

    func registerToken(fcmToken: String, externalCustomerId: String) async throws {
        let url = "\(notificationUrl)/register-device"
        let params = MeldTokenRegistrationRequest(
            externalCustomerId: externalCustomerId,
            fcmToken: fcmToken,
            platform: "ios"
        )
        let res: MeldTokenRegistrationResponse = try await Meld.call(url: url, method: "POST", params: params)
    }

    public static func needFetchingTxs(xpub: String) -> Bool {
        let defaults = UserDefaults(suiteName: Bundle.main.appGroup)
        let value = defaults?.bool(forKey: "\(MELD_PREFIX_LABEL)_\(xpub)") ?? false
        logger.info("Meld fetching txs needed: \(value)")
        return value
    }

    public static func enableFetchingTxs(xpub: String, enable: Bool) {
        let defaults = UserDefaults(suiteName: Bundle.main.appGroup)
        defaults?.setValue(enable, forKey: "\(MELD_PREFIX_LABEL)_\(xpub)")
        logger.info("Meld fetching txs enabled: \(enable)")
    }
}
