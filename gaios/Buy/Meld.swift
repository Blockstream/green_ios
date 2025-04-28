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
}

struct MeldWidgetResponse: Codable {
    let id: String
    let customerId: String?
    let widgetUrl: String?
    let token: String?
    let message: String?
}

struct Meld {

    private static let MELD_API_PRODUCTION = "https://ramps.blockstream.com"
    private static let MELD_API_SANDBOX = "https://ramps.sandbox.blockstream.com"

    let isSandboxEnvironment: Bool
    var meldApiUrl: String {
        isSandboxEnvironment ? Meld.MELD_API_SANDBOX : Meld.MELD_API_PRODUCTION
    }

    func quote(_ params: MeldQuoteParams) async throws -> [MeldQuoteItem] {
        let url = "\(meldApiUrl)/payments/crypto/quote"
        let data = try params.encoded()
        let res = try await Meld.call(url: url, data: data)
        let response = try JSONDecoder().decode(MeldQuoteResponse.self, from: res)
        if let message = response.message {
            print("--------> err")
            throw GaError.GenericError(message)
        }
        let quotes = response.quotes
        print("--------> quotes")
        return quotes.sorted { $0.destinationAmount < $1.destinationAmount }
    }

    func widget(_ params: MeldWidgetParams) async throws -> String {
        let url = "\(meldApiUrl)/crypto/session/widget"
        let data = try params.encoded()
        let res = try await Meld.call(url: url, data: data)
        let response = try JSONDecoder().decode(MeldWidgetResponse.self, from: res)
        if let widgetUrl = response.widgetUrl {
            return widgetUrl
        } else if let message = response.message {
            throw GaError.GenericError(message)
        } else {
            throw GaError.GenericError("Invalid request")
        }
    }

    static func call(url: String, data: Data) async throws -> Data {
        let url = URL(string: url)!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpMethod = "POST"
        request.httpBody = data
        request.timeoutInterval = 30
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

}
extension MeldQuoteItem {
    func btc() -> String? {
        let amount = Int64(destinationAmount * 100_000_000)
        return Balance.fromSatoshi(amount, assetId: "btc")?.toText()
    }
}
