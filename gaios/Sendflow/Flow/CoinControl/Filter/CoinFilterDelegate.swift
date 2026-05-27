import Foundation

protocol CoinFilterDelegate: AnyObject {
    func didSelectFilter(filters: Set<CoinFilter>)
}
