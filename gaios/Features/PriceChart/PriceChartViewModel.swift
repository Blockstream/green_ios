@MainActor
final class PriceChartViewModel {
    private(set) var priceChartModel: PriceChartModel?
    private(set) var isLoading = false
    var timeFrame: ChartTimeFrame = .day

    func cellModel(showsBuyButton: Bool = false) -> PriceChartCellModel {
        PriceChartCellModel(
            priceChartModel: priceChartModel,
            currency: priceChartModel?.currency,
            isReloading: isLoading,
            showsBuyButton: showsBuyButton)
    }

    func load(currency: String = "USD") async {
        let currentCurrency = currency.lowercased()

        if let cached = await BitcoinPriceService.shared.cachedPriceChart(currency: currentCurrency) {
            updatePriceChart(cached, isLoading: false)
            return
        }

        updatePriceChart(priceChartModel, isLoading: priceChartModel == nil)

        do {
            let priceChart = try await BitcoinPriceService.shared.fetch(currency: currentCurrency)
            updatePriceChart(priceChart, isLoading: false)
        } catch {
            updatePriceChart(priceChartModel, isLoading: false)
        }
    }

    private func updatePriceChart(_ priceChart: PriceChartModel?, isLoading: Bool) {
        priceChartModel = priceChart
        self.isLoading = isLoading
    }
}
