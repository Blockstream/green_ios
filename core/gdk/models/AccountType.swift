import Foundation

public enum AccountType: String, CaseIterable, Codable, Comparable, Equatable, CustomStringConvertible, Sendable {

    // Multisig
    case standard = "2of2"
    case ampAccount = "2of2_no_recovery"
    case twoOfThree = "2of3"

    // Singlesig
    case bip44Legacy = "p2pkh"
    case bip49SegwitWrapped = "p2sh-p2wpkh"
    case bip84Segwit = "p2wpkh"
    case bip86Taproot = "p2tr"

    // Lightning
    case lightning = "lightning"

    // Lwk
    case amp2Account = "amp2"

    // Others
    case unknown = "unknown"

    public var description: String {
        switch self {
        case .bip44Legacy: return "Legacy"
        case .bip49SegwitWrapped: return "Legacy SegWit"
        case .bip84Segwit: return "Standard"
        case .bip86Taproot: return "Taproot"
        case .lightning: return "Lightning"
        case .standard: return "2FA Protected"
        case .ampAccount: return "AMP"
        case .amp2Account: return "AMP2"
        case .twoOfThree: return "2of3 with 2FA"
        case .unknown: return self.rawValue
        }
    }

    public var title: String {
        switch self {
        case .standard: return "2FA Protected"
        case .ampAccount: return "AMP"
        case .amp2Account: return "AMP2"
        case .twoOfThree: return "2of3 with 2FA"
        case .bip44Legacy: return "Legacy"
        case .bip49SegwitWrapped: return "Legacy SegWit"
        case .bip84Segwit: return "Standard"
        case .bip86Taproot: return "Taproot"
        case .lightning: return "Lightning"
        case .unknown: return "Unknown"
        }
    }

    public var string: String { title }

    public var singlesig: Bool {
        switch self {
        case .bip44Legacy, .bip49SegwitWrapped, .bip84Segwit, .bip86Taproot:
            return true
        default:
            return false
        }
    }

    public var lightning: Bool {
        return self == .lightning
    }

    public var multisig: Bool {
        return !singlesig && !lightning
    }

    public static func < (a: AccountType, b: AccountType) -> Bool {
        let rules: [AccountType] = [
            .bip49SegwitWrapped,
            .bip84Segwit,
            .bip86Taproot,
            .amp2Account,
            .standard,
            .ampAccount,
            .twoOfThree,
            .lightning
        ]
        return rules.firstIndex(of: a) ?? 0 < rules.firstIndex(of: b) ?? 0
    }

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
            return "\(description)"
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

    public static func byGDKType(_ name: String) -> AccountType {
        return AccountType(rawValue: name) ?? .unknown
    }
}

public enum RecoveryKeyType {
    case hw
    case newPhrase
    case existingPhrase
    case publicKey
}
