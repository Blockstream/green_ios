import Foundation
import core

enum PromoTarget: String, Decodable {
    case jadePlusUser = "jadeplus_user"
    case jadeUser = "jade_user"
    case onlySoftwareWallet = "only_sww"
}

public struct Promo: Decodable {
    let id: String
    let target: PromoTarget?
    let title: String
    let description: String
    let cta: PromoCta
    let imageUrl: String

    struct PromoCta: Decodable {
        let label: String
        let url: String
    }

    var isVisible: Bool {
        let visibleHardwareWallets = WalletsStorage.shared.hwsVisible
        if let target {
            switch target {
            case .jadePlusUser:
                let visibleV2s = visibleHardwareWallets.filter { ($0.boardType == .v2 || $0.boardType == .v2c) }.count
                if visibleV2s == 0 { return false }
            case .jadeUser:
                let visibleV1s = visibleHardwareWallets.filter { ($0.boardType == .v1 || $0.boardType == .v1_1) }.count
                let visibleV2s = visibleHardwareWallets.filter { ($0.boardType == .v2 || $0.boardType == .v2c) }.count
                guard visibleV1s > 0 && visibleV2s == 0 else { return false }
            case .onlySoftwareWallet:
                if visibleHardwareWallets.count > 0 { return false }
            }
        }
        return true
    }
}
