import Foundation

actor BitcoinPriceService {

    static let shared = BitcoinPriceService()
    private static let session: URLSession = {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10.0
        sessionConfig.timeoutIntervalForResource = 10.0
        return URLSession(configuration: sessionConfig)
    }()
    private let priceCacheTTL: TimeInterval = 60 * 60
    private var priceCacheByCurrency: [String: PriceChartModel] = [:]
    private var priceCacheDates: [String: Date] = [:]
    private var priceFetchTasks: [String: (id: UUID, task: Task<PriceChartModel, Error>)] = [:]

    @discardableResult
    func fetch(currency: String) async throws -> PriceChartModel {
        let currency = currency.lowercased()
        if let cached = cachedPriceChart(currency: currency) {
            return cached
        }

        let (id, task) = priceFetchTask(currency: currency) {
            try await Self.fetchPriceChart(currency: currency)
        }

        do {
            let model = try await task.value
            setPriceCache(model, currency: currency)
            removePriceFetchTask(currency: currency, id: id)
            return model
        } catch {
            removePriceFetchTask(currency: currency, id: id)
            throw error
        }
    }

    func cachedPriceChart(currency: String) -> PriceChartModel? {
        let currency = currency.lowercased()
        guard let model = priceCacheByCurrency[currency], let date = priceCacheDates[currency] else {
            return nil
        }
        guard Date().timeIntervalSince(date) < priceCacheTTL else {
            priceCacheByCurrency.removeValue(forKey: currency)
            priceCacheDates.removeValue(forKey: currency)
            return nil
        }
        return model
    }

    private func priceFetchTask(currency: String, create: @escaping () async throws -> PriceChartModel) -> (UUID, Task<PriceChartModel, Error>) {
        if let task = priceFetchTasks[currency] {
            return (task.id, task.task)
        }
        let id = UUID()
        let task = Task<PriceChartModel, Error> {
            try await create()
        }
        priceFetchTasks[currency] = (id, task)
        return (id, task)
    }

    private func removePriceFetchTask(currency: String, id: UUID) {
        guard priceFetchTasks[currency]?.id == id else { return }
        priceFetchTasks.removeValue(forKey: currency)
    }

    private func setPriceCache(_ model: PriceChartModel, currency: String) {
        priceCacheByCurrency[currency] = model
        priceCacheDates[currency] = Date()
    }

    private static func fetchPriceChart(currency: String) async throws -> PriceChartModel {
        print("PriceChart remote fetch currency: \(currency)")
        let url = URL(string: "https://green-btc-chart.blockstream.com/api/v1/bitcoin/prices?currency=\(currency)")!
        let request = URLRequest(url: url)

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(PriceChartModel.self, from: data)
    }
}
