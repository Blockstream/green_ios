import Foundation
import UIKit

enum BuyMoreActions: CaseIterable {
    case verify
    var title: String {
        switch self {
        case .verify:
            return "Verify Address".localized
        }
    }
}
class MoreActionsViewModel {
    var title = "More actions".localized
    var actions = BuyMoreActions.allCases
}
