import Foundation
import gdk

extension AccountType {
    public var network: String {
        if lightning {
            return "Lightning"
        } else if singlesig {
            return "Singlesig"
        } else {
            return "Multisig"
        }
    }
    public var shortText: String {
        if lightning {
            return "Fastest"
        } else {
            return "\(shortString)"
        }
    }
    public var longText: String {
        if lightning {
            return "Fastest"
        } else {
            return "\(string)"
        }
    }
    public var path: String {
        if lightning {
            return network
        } else {
            return "\(network) / \(shortText)"
        }
    }
}
