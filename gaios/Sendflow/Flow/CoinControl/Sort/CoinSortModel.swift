import Foundation

enum CoinSort: String, CaseIterable {
    case amountDescending
    case amountAscending
    case dateDescending
    case dateAscending

    static let defaultSort: CoinSort = .amountDescending

    var title: String {
        switch self {
        case .amountDescending: return "Amount (High to Low)".localized
        case .amountAscending: return "Amount (Low to High)".localized
        case .dateDescending: return "Newest".localized
        case .dateAscending: return "Oldest".localized
        }
    }
}
