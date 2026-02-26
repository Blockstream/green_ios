import LiquidWalletKit
import Foundation
import core
import gdk
import greenaddress

enum PaymentTarget {
    case bitcoinAddress(BitcoinAddress)
    case liquidAddress(LiquidWalletKit.Address)
    case lightningInvoice(Bolt11Invoice)
    case lightningOffer(String)
    case lnUrl(String)
    case bip353(String)
    case bip21(Bip21)
    case bip321(Bip321)
    case liquidBip21(LiquidBip21)
    case psbt(String)
    case pset(String)
    case privateKey(String)
}

extension PaymentTarget {
    func chain() -> NetworkChainType {
        switch self {
        case .bip21, .bip353, .bip321, .bitcoinAddress, .psbt, .privateKey:
            return .bitcoin
        case .liquidAddress, .liquidBip21, .pset:
            return .liquid
        case .lightningInvoice, .lightningOffer, .lnUrl:
            return .lightning
        }
    }
    func assetId() -> String? {
        switch self {
        case .liquidBip21(let bip21):
            return bip21.asset
        case .liquidAddress:
            return nil
        case .lightningInvoice, .lightningOffer, .lnUrl:
            return AssetInfo.lightningId
        default:
            return nil
        }
    }
}

enum NetworkChainType {
    case bitcoin
    case liquid
    case lightning
}
