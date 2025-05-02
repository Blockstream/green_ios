enum ChartTimeFrame {
    case day
    case week
    case month
    case year
//    case ytd
    case all

    var name: String {
        switch self {
        case .day:
            return "1D".localized
        case .week:
            return "1W".localized
        case .month:
            return "1M".localized
        case .year:
            return "1Y".localized
//        case .ytd:
//            return "YTD".localized
        case .all:
            return "ALL".localized
        }
    }
}
struct PriceChartCellModel {
    let priceChartModel: PriceChartModel?
    let currency: String?
    let isReloading: Bool?
}
