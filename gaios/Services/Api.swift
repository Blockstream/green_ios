import Foundation

enum ApiCurrency: String {
    case usd
}

class Api {

    static let shared = Api()
    var priceCache: PriceChartModel?
    func fetch(currency: ApiCurrency = ApiCurrency.usd, days: Int = 365) async throws {
        let url = URL(string: "https://green-btc-chart.blockstream.com/api/v1/bitcoin/prices?currency=\(currency.rawValue)&days=\(days)")!
        let request = URLRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        priceCache = try JSONDecoder().decode(PriceChartModel.self, from: data)
    }
}
