import Foundation
import core
import UIKit


// Section of settings
enum WOSection: String, Codable, CaseIterable {
    case Multisig
    case Singlesig

    var icon: UIImage {
        switch self {
        case .Multisig:
            return UIImage(named: "ic_keys_invert")!
        case .Singlesig:
            return UIImage(named: "ic_key")!
        }
    }
}
