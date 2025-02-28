import UIKit

enum TransactActions {
    case buy
    case send
    case receive

    var name: String {
        switch self {
        case .buy:
            return "Buy"
        case .send:
            return "Send"
        case .receive:
            return "Receive"
        }
    }
    var icon: UIImage {
        switch self {
        case .buy:
            UIImage(named:"ic_buy")!.maskWithColor(color: .white)
        case .send:
            UIImage(named:"ic_send")!.maskWithColor(color: .white)
        case .receive:
            UIImage(named:"ic_receive")!.maskWithColor(color: .white)
        }
    }
}
