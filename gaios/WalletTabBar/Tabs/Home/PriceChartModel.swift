import Foundation

struct ChartPoint {
    let ts: Double
    let value: Double
}

struct PriceChartModel: Codable {
    var currency: String
    var last_refresh: String
    var prices_full: [[Double]]
    var prices_day: [[Double]]

    var fullData: [ChartPoint] {
        let ls: [ChartPoint] = prices_full.map {
            ChartPoint(ts: $0[0], value: $0[1])
        }
        return ls.sorted { $0.ts < $1.ts }
    }

    var dayData: [ChartPoint] {
        let ls: [ChartPoint] = prices_day.map {
            ChartPoint(ts: $0[0], value: $0[1])
        }
        return ls.sorted { $0.ts < $1.ts }
    }
}
