import LiquidWalletKit

public struct BoltzReverseSwapInfoLBTC: Codable {
    public let hash: String
    public let rate: Int
    public let limits: BoltzSwapInfoLimits
    public let fees: BoltzReverseSwapInfoFees
}

public struct BoltzSubmarineSwapInfoLBTC: Codable {
    public let hash: String
    public let rate: Int
    public let limits: BoltzSwapInfoLimits
    public let fees: BoltzSwapInfoFees
}

public struct BoltzSwapInfoLimits: Codable {
    public let maximal: Int64
    public let minimal: Int64
}

public struct BoltzReverseSwapInfoFees: Codable {
    public let percentage: Double
    public let minerFees: BoltzSwapInfominerFees
}

public struct BoltzSwapInfoFees: Codable {
    public let percentage: Double
    public let minerFees: Int64
}

public struct BoltzSwapInfominerFees: Codable {
    public let claim: UInt64
    public let lockup: UInt64
}

public enum BoltzSwapTypes: String {
    case Submarine = "submarine"
    case ReverseSubmarine = "reverse"
    case Chain = "chain"
}
