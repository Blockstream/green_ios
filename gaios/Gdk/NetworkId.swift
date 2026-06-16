import Foundation
import UIKit
import core

extension NetworkId {

    func icons() -> (UIImage, UIImage) {
        switch self {
        case .greenMainnet:
            return (UIImage(named: "ic_keys_invert")!, UIImage(named: "ntw_btc")!)
        case .electrumMainnet:
            return (UIImage(named: "ic_key")!, UIImage(named: "ntw_btc")!)
        case .greenLiquid:
            return (UIImage(named: "ic_keys_invert")!, UIImage(named: "ntw_liquid")!)
        case .electrumLiquid:
            return (UIImage(named: "ic_key")!, UIImage(named: "ntw_liquid")!)
        case .greenTestnet:
            return (UIImage(named: "ic_keys_invert")!, UIImage(named: "ntw_testnet")!)
        case .electrumTestnet:
            return (UIImage(named: "ic_key")!, UIImage(named: "ntw_testnet")!)
        case .greenTestnetLiquid:
            return (UIImage(named: "ic_keys_invert")!, UIImage(named: "ntw_testnet_liquid")!)
        case .electrumTestnetLiquid:
            return (UIImage(named: "ic_key")!, UIImage(named: "ntw_testnet_liquid")!)
        case .lightningMainnet:
            return (UIImage(named: "ic_key")!, UIImage(named: "ntw_btc")!)
        case .lwkMainnet:
            return (UIImage(named: "ic_key")!, UIImage(named: "ntw_liquid")!)
        }
    }

    func color() -> UIColor {
        switch self {
        case .greenMainnet, .electrumMainnet:
            return UIColor.gAccountOrange()
        case .greenLiquid, .electrumLiquid, .lwkMainnet:
            return UIColor.gAccountLightBlue()
        case .greenTestnet, .electrumTestnet, .greenTestnetLiquid, .electrumTestnetLiquid:
            return UIColor.gAccountTestGray()
        case .lightningMainnet:
            return UIColor.yellow
        }
    }
}
