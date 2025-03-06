import Foundation

struct ChartPoint {
    let ts: Double
    let value: Double
}

struct PriceChartModel: Codable {
    var currency: String
    var last_refresh: String
    var prices: [[Double]]
    var list: [ChartPoint] {
        let ls: [ChartPoint] = prices.map {
            ChartPoint(ts: $0[0], value: $0[1])
        }
        return ls.sorted { $0.ts < $1.ts }
    }
    static func loadJson() -> PriceChartModel? {
        if let url = Bundle.main.url(forResource: "price_chart_mock", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let jsonData = try decoder.decode(PriceChartModel.self, from: data)
                return jsonData
            } catch {
                print("error:\(error)")
            }
        }
        return nil
    }

    static var mock: [ChartPoint] {
        if let chartModel = PriceChartModel.loadJson() {
            let ls: [ChartPoint] = chartModel.prices.map {
                ChartPoint(ts: $0[0], value: $0[1])
            }
            return ls.sorted { $0.ts < $1.ts }
        }
        return []
    }
}
