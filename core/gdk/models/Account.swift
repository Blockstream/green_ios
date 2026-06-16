import Foundation

public struct Account: Codable, Equatable, Comparable, Sendable {
    
    enum CodingKeys: String, CodingKey {
        case gdkName = "name"
        case pointer
        case receivingId = "receiving_id"
        case type
        case recoveryXpub = "recovery_xpub"
        case hidden
        case bip44Discovered = "bip44_discovered"
        case coreDescriptors = "core_descriptors"
        case extendedPubkey = "slip132_extended_pubkey"
        case userPath = "user_path"
    }
    
    public let gdkName: String
    public let pointer: UInt32
    public let receivingId: String?
    public let type: AccountType
    public let bip44Discovered: Bool?
    public let recoveryXpub: String?
    public let hidden: Bool
    public let coreDescriptors: [String]?
    public let extendedPubkey: String?
    public let userPath: [Int]?
    
    public var networkInjected: GdkNetwork?
    
    public init(
        gdkName: String,
        pointer: UInt32,
        receivingId: String? = nil,
        type: AccountType,
        bip44Discovered: Bool? = nil,
        recoveryXpub: String? = nil,
        hidden: Bool = false,
        coreDescriptors: [String]? = nil,
        extendedPubkey: String? = nil,
        userPath: [Int]? = nil,
        networkInjected: GdkNetwork?) {
            self.gdkName = gdkName
            self.pointer = pointer
            self.receivingId = receivingId
            self.type = type
            self.bip44Discovered = bip44Discovered
            self.recoveryXpub = recoveryXpub
            self.hidden = hidden
            self.coreDescriptors = coreDescriptors
            self.extendedPubkey = extendedPubkey
            self.userPath = userPath
            self.networkInjected = networkInjected
        }
    
    mutating func setup(network: GdkNetwork) async {
        self.networkInjected = network
    }
    
    public var network: GdkNetwork { networkInjected!}
    public var gdkNetwork: GdkNetwork { networkInjected!}
    private var policyAssetId: String? { networkInjected?.policyAsset }
    public var id: String { "\(networkInjected?.network ?? ""):\(pointer)" }
    public var bip32Pointer: UInt32 { isSinglesig ? pointer / 16 : pointer}
    public var accountNumber: UInt32 { bip32Pointer + 1 }
    public var isSinglesig: Bool { return network.singlesig }
    public var isMultisig: Bool { return network.multisig }
    public var isLightning: Bool { return type == .lightning }
    public var isLwk: Bool { return network.networkId == .lwkMainnet || network.networkId == .lwkTestnet }
    public var networkId: NetworkId {
        return NetworkId(network: network.network)!
    } // Assuming network.id is String
    public var isBitcoin: Bool { return network.bitcoin }
    public var isBitcoinOrLightning: Bool { return network.bitcoinOrLightning }
    public var isBitcoinMainnet: Bool { return network.bitcoinMainnet }
    public var isLiquidMainnet: Bool { return network.liquidMainnet }
    public var isBitcoinTestnet: Bool { return network.bitcoinTestnet }
    public var isLiquidTestnet: Bool { return network.liquidTestnet }
    public var isLiquid: Bool { return network.liquid }
    public var isAmp: Bool {
        return type == .ampAccount || type == .amp2Account
    }

    var outputDescriptors: String? {
        return coreDescriptors?.joined(separator: "\n")
    }
    
    private var weight: Int {
        if isBitcoin && isSinglesig { return 0 }
        if isBitcoin && isMultisig { return 1 }
        if isLightning { return 2 }
        if isLiquid && isSinglesig { return 3 }
        if isLiquid && isMultisig && !isAmp { return 4 }
        if isLiquid && isMultisig && isAmp { return 5 }
        return 6
    }
    
    public static func < (lhs: Account, rhs: Account) -> Bool {
        if lhs.weight == rhs.weight {
            if lhs.type == rhs.type {
                return lhs.pointer < rhs.pointer
            } else {
                return lhs.type < rhs.type
            }
        } else {
            return lhs.weight < rhs.weight
        }
    }
    
    public static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.pointer == rhs.pointer && lhs.network.network == rhs.network.network
    }
    
    public var networkBackend: NetworkBackend? {
        WalletManager.current?.networkBackendOrNil(networkId)
    }
    public var gdkSession: SessionManager? {
        (networkBackend as? GdkNetworkBackend)?.session
    }
    public var lightningSession: LightningSessionManager? {
        (networkBackend as? GlNetworkBackend)?.session
    }
    
    public var name: String {
        if !gdkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return gdkName
        }
        
        switch type {
        case .bip44Legacy, .bip49SegwitWrapped, .bip84Segwit, .bip86Taproot:
            let typeString: String
            switch type {
            case .bip44Legacy: typeString = "Legacy"
            case .bip49SegwitWrapped: typeString = "Legacy SegWit"
            case .bip84Segwit: typeString = "SegWit"
            default: typeString = "Taproot"
            }
            if accountNumber == 1 {
                return "\(typeString) Account \(accountNumber)"
            } else {
                return "\(typeString) \(accountNumber)"
            }
        case .standard: return "2FA Protected"
        case .ampAccount: return "AMP"
        case .amp2Account: return "AMP2"
        case .twoOfThree: return "2of3"
        case .lightning: return "Lighning" // Kept exact typo from your source string
        case .unknown: return "Unknown"
        }
    }
    public var localizedName: String {
        if !name.isEmpty {
            return name
        }
        let subaccounts = WalletManager.current?.accounts ?? []
        let subaccountsSameType = subaccounts.filter { $0.type == self.type && $0.network == self.network }
        let network = gdkNetwork.liquid ? " Liquid " : " "
        if subaccountsSameType.count > 1 {
            let index = subaccountsSameType.filter { $0.pointer < self.pointer }.count
            if index > 0 {
                return "\(type.string)\(network)\(index+1)"
            }
        }
        return "\(type.string)\(network)"
    }
    
    public func assets(_ wm: WalletManager) throws -> Assets {
        try wm.accountBackend(self).assets
    }
    public func isFunded(_ wm: WalletManager) throws -> Bool {
        try assets(wm).values.reduce(0, +) > 0
    }
    public func hasTxs(_ wm: WalletManager) throws -> Bool {
        try wm.accountBackend(self).hasTxs
    }
}
