import Foundation
import core

enum PolicyCellType: String, CaseIterable {
    case NativeSegwit
    case LegacySegwit
    case Lightning
    case TwoFAProtected
    case TwoOfThreeWith2FA
    // case Taproot
    case Amp

    var accountType: AccountType {
        switch self {
        case .NativeSegwit:
            return .segWit
        case .Lightning:
            return .lightning
        case .TwoFAProtected:
            return .standard
        case .TwoOfThreeWith2FA:
            return .twoOfThree
        case .LegacySegwit:
            return .segwitWrapped
        case .Amp:
            return .amp
        }
    }

    func getNetwork(testnet: Bool, liquid: Bool) -> NetworkId? {
        let btc: [PolicyCellType: NetworkId] =
        [.LegacySegwit: .electrumMainnet, .Lightning: .lightningMainnet, .TwoFAProtected: .greenMainnet,
         .TwoOfThreeWith2FA: .greenMainnet, .NativeSegwit: .electrumMainnet, .Amp: .greenMainnet]
        let test: [PolicyCellType: NetworkId] =
        [.LegacySegwit: .electrumTestnet, .TwoFAProtected: .greenTestnet,
         .TwoOfThreeWith2FA: .greenTestnet, .NativeSegwit: .electrumTestnet, .Amp: .greenTestnet]
        let lbtc: [PolicyCellType: NetworkId] =
        [.LegacySegwit: .electrumLiquid, .TwoFAProtected: .greenLiquid,
         .TwoOfThreeWith2FA: .greenLiquid, .NativeSegwit: .electrumLiquid, .Amp: .greenLiquid]
        let ltest: [PolicyCellType: NetworkId] =
        [.LegacySegwit: .electrumTestnetLiquid, .TwoFAProtected: .greenTestnetLiquid,
         .TwoOfThreeWith2FA: .greenTestnetLiquid, .NativeSegwit: .electrumTestnetLiquid, .Amp: .greenTestnetLiquid]
        if liquid && testnet { return ltest[self] }
        if liquid && !testnet { return lbtc[self] }
        if !liquid && testnet { return test[self] }
        return btc[self]
    }
}
