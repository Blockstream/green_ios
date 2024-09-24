import Foundation
import UIKit
import gdk

struct PolicyCellModel {

    var isSS: Bool { policy.accountType.singlesig }
    var isLight: Bool { policy.accountType.lightning }
    var type: String { policy.accountType.network }
    var typeDesc: String { policy.accountType.shortText }
    var name: String { policy.accountType.string }
    var hint: String
    var policy: PolicyCellType

    static func from(policy: PolicyCellType) -> PolicyCellModel {
        switch policy {
        case .LegacySegwit:
            return PolicyCellModel(hint: "id_simple_portable_standard".localized, policy: policy)
        case .Lightning:
            return PolicyCellModel(hint: "id_fast_transactions_on_the".localized, policy: policy)
        case .TwoFAProtected:
            return PolicyCellModel(hint: "id_quick_setup_2fa_account_ideal".localized, policy: policy)
        case .TwoOfThreeWith2FA:
            return PolicyCellModel(hint: "id_permanent_2fa_account_ideal_for".localized, policy: policy)
        case .NativeSegwit:
            return PolicyCellModel(hint: "id_cheaper_singlesig_option".localized, policy: policy)
        // case .Taproot:
        //    return PolicyCellModel(hint: "Cheaper and more private singlesig option. Addresses are Bech32m.", policy: policy)
        case .Amp:
            return PolicyCellModel(hint: "id_account_for_special_assets".localized, policy: policy)
        }
    }
}
