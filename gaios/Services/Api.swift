import Foundation

class Api {

    static let shared = Api()
    var priceCache: PriceChartModel?
    var currency: String?

    func fetch(currency: String) async throws {
        self.currency = currency
        self.priceCache = nil
        let url = URL(string: "https://green-btc-chart.blockstream.com/api/v1/bitcoin/prices?currency=\(currency)")!
        let request = URLRequest(url: url)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 5.0
        let session = URLSession(configuration: sessionConfig)

        let (data, _) = try await session.data(for: request)
        priceCache = try? JSONDecoder().decode(PriceChartModel.self, from: data)
    }
}

// let url = URL(string: "https://green-btc-chart.blockstream.com/api/v1/bitcoin/prices?currency=\(currency.rawValue)&days=\(days)")!
