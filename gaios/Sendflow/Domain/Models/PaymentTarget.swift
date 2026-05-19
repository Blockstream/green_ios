import LiquidWalletKit
import Foundation
import core
import gdk
import greenaddress

enum PaymentTarget {
    case bitcoinAddress(BitcoinAddress)
    case liquidAddress(LiquidWalletKit.Address)
    case lightningInvoice(Bolt11Invoice)
    case lightningOffer(String, LightningPayment)
    case lnUrl(String, LiquidWalletKit.Payment)
    case bip353(String, LiquidWalletKit.Payment)
    case bip21(Bip21)
    case bip321(Bip321)
    case liquidBip21(LiquidBip21)
    case psbt(String)
    case pset(String)
    case privateKey(String)
}

enum PaymentRail: Hashable {
    case bitcoin
    case liquid
    case lightning
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
    
    func eligibleRails() -> [PaymentRail] {
        switch self {
        case .bitcoinAddress, .bip21, .psbt, .privateKey:
            return [.bitcoin]
        case .liquidAddress, .liquidBip21, .pset:
            return [.liquid]
        case .lightningInvoice(let invoice):
            if invoice.amountMilliSatoshis() == nil {
                return [.lightning]
            }
            return [.liquid, .lightning]
        case .lightningOffer:
            // BOLT12 is liquid-only for now; Lightning can be re-enabled later.
            return [.liquid]
        case .lnUrl:
            return [.liquid, .lightning]
        case .bip353:
            // BIP-353 resolves to any kind of payment via DNS; accept any rail
            // here and let the routing layer re-validate after resolution.
            return [.bitcoin, .liquid, .lightning]
        default:
            return []
        }
    }

    // UI-only flag used by the amount screen to apply the LNURL/BOLT12
    // swap-style layout on the Liquid rail.
    var usesSubmarineAmountUi: Bool {
        switch self {
        case .lnUrl, .lightningOffer:
            return true
        default:
            return false
        }
    }
}

enum NetworkChainType {
    case bitcoin
    case liquid
    case lightning
}
