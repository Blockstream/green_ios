import Foundation
import UIKit
import core

enum CoinFilter: CaseIterable {
    case dust
    case legacyRecovery
    case expired

    var title: String {
        switch self {
        case .expired: return "2FA Expired".localized
        case .dust: return "Dust".localized
        case .legacyRecovery: return "Legacy Recovery".localized
        }
    }
    var icon: UIImage {
        switch self {
        case .expired: return UIImage(resource: .icTimerLight)
        case .dust: return UIImage(resource: .icBrushLight)
        case .legacyRecovery: return UIImage(resource: .icArrowsClockwise)
        }
    }

    public static func filters(for subaccount: Account?) -> [CoinFilter] {
        var filters: [CoinFilter] = []

        if subaccount?.type != .twoOfThree && subaccount?.type != .ampAccount {
            filters.append(.expired)
        }

        if subaccount?.gdkNetwork.liquid != true {
            filters.append(.dust)
        }

        if subaccount?.gdkNetwork.liquid != true && subaccount?.type == .standard {
            filters.append(.legacyRecovery)
        }

        return filters
    }
}
