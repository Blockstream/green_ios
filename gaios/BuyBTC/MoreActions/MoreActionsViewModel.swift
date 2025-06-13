import Foundation
import UIKit

enum BuyMoreActions: CaseIterable {
    case verify
    var title: String {
        switch self {
        case .verify:
            return "id_verify_address".localized
        }
    }
}
class MoreActionsViewModel {
    var title = "id_more_actions".localized
    var actions = BuyMoreActions.allCases
}
