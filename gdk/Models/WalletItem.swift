import Foundation

public class WalletItem: Codable, Equatable, Comparable {

    enum CodingKeys: String, CodingKey {
        case name
        case pointer
        case receivingId = "receiving_id"
        case type
        case satoshi
        case recoveryXpub = "recovery_xpub"
        case hidden
        case bip44Discovered = "bip44_discovered"
        case coreDescriptors = "core_descriptors"
        case extendedPubkey = "slip132_extended_pubkey"
        case userPath = "user_path"
    }

    public let name: String
    public let pointer: UInt32
    public let receivingId: String
    public let type: AccountType
    public let bip44Discovered: Bool?
    public let recoveryXpub: String?
    public let hidden: Bool
    public var network: String?
    public let coreDescriptors: [String]?
    public let extendedPubkey: String?
    public let userPath: [Int]?
    public var hasTxs: Bool = false
    public var satoshi: [String: Int64]?
    public var transactions = [Transaction]()

    public var networkType: NetworkSecurityCase { NetworkSecurityCase(rawValue: network!)! }
    public var gdkNetwork: GdkNetwork { networkType.gdkNetwork }
    
    public var id: String {
        "\(network ?? ""):\(pointer)"
    }
    public var btc: Int64? {
        let feeAsset = gdkNetwork.getFeeAsset()
        return satoshi?[feeAsset]
    }

    public var bip32Pointer: UInt32 { isSinglesig ? pointer / 16 : pointer}
    public var accountNumber: UInt32 { bip32Pointer + 1 }

    public var manyAssets: Int {
        satoshi?.filter { $0.value > 0 }.keys.count ?? 0
    }

    public func hasAsset(_ assetId: String) -> Bool {
        satoshi?.filter { $0.key == assetId && $0.value > 0 }.count ?? 0 > 0
    }

    public var isMultisig: Bool {
        switch type {
        case .standard, .amp, .twoOfThree:
            return true
        default:
            return false
        }
    }

    public var isSinglesig: Bool {
        switch type {
        case .legacy, .segwitWrapped, .segWit, .taproot:
            return true
        default:
            return false
        }
    }

    public var isLightning: Bool {
        type == .lightning
    }

    public static func == (lhs: WalletItem, rhs: WalletItem) -> Bool {
        return lhs.network == rhs.network &&
            lhs.name == rhs.name &&
            lhs.pointer == rhs.pointer &&
            lhs.receivingId == rhs.receivingId &&
            lhs.type == rhs.type
    }

    public static func < (lhs: WalletItem, rhs: WalletItem) -> Bool {
        let lhsNetwork = lhs.gdkNetwork
        let rhsNetwork = rhs.gdkNetwork
        if lhsNetwork == rhsNetwork {
            if lhs.type == rhs.type {
                return lhs.pointer < rhs.pointer
            }
            return lhs.type < rhs.type
        }
        return lhsNetwork < rhsNetwork
    }
    public init(name: String, pointer: UInt32, receivingId: String, type: AccountType, bip44Discovered: Bool? = nil, recoveryXpub: String? = nil, hidden: Bool, network: String? = nil, coreDescriptors: [String]? = nil, extendedPubkey: String? = nil, userPath: [Int]? = nil, hasTxs: Bool = false, satoshi: [String: Int64]? = nil) {
        self.name = name
        self.pointer = pointer
        self.receivingId = receivingId
        self.type = type
        self.bip44Discovered = bip44Discovered
        self.recoveryXpub = recoveryXpub
        self.hidden = hidden
        self.network = network
        self.coreDescriptors = coreDescriptors
        self.extendedPubkey = extendedPubkey
        self.userPath = userPath
        self.hasTxs = hasTxs
        self.satoshi = satoshi
    }
}
