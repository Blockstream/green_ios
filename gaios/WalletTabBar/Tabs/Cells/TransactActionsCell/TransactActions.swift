import UIKit

enum TransactActions {
    case buy
    case send
    case receive
    case swap

    var name: String {
        switch self {
        case .buy:
            return "Buy".localized
        case .send:
            return "id_send".localized
        case .receive:
            return "Receive".localized
        case .swap:
            return "id_swap".localized
        }
    }
    var icon: UIImage {
        switch self {
        case .buy:
            UIImage(resource: .icCoinsLight).withTintColor(.white, renderingMode: .alwaysOriginal)
        case .send:
            UIImage(resource: .icArrowLineUpLight).withTintColor(.white, renderingMode: .alwaysOriginal)
        case .receive:
            UIImage(resource: .icArrowLineDownLight).withTintColor(.white, renderingMode: .alwaysOriginal)
        case .swap:
            UIImage(resource: .icArrowsDownUpLight).withTintColor(.white, renderingMode: .alwaysOriginal)
        }
    }
}
