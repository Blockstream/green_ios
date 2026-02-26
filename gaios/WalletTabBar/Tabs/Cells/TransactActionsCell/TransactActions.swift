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
            UIImage(named:"ic_buy")!.maskWithColor(color:.white)
        case .send:
            UIImage(named:"ic_send")!.maskWithColor(color:.white)
        case .receive:
            UIImage(named:"ic_receive")!.maskWithColor(color:.white)
        case .swap:
            UIImage(named:"ic_tx_swap")!.maskWithColor(color:.white)
        }
    }
}
