import Foundation
import UIKit
import core

enum PreferenceCellState: String {
    case on = "ON"
    case off = "OFF"
    case unknown
}
enum PreferenceType {
    case bio
    case pin
    case genuineCheck
    case fwUpdate
    case recoveryPhrase
}
class PreferenceCellModel {
    var state: PreferenceCellState
    var type: PreferenceType

    init(preferenceType: PreferenceType,
         state: PreferenceCellState) {
        self.state = state
        self.type = preferenceType
    }
    var hasTouchID: Bool {
        return AuthenticationTypeHandler.biometryType == .touchID
    }
    var icImg: UIImage? {
        switch self.type {
        case .bio:
            return UIImage(systemName: icName)?.maskWithColor(color: UIColor.gGrayTxt())
        default:
            return UIImage(named: icName)
        }
    }
    var title: String {
        switch self.type {
        case .bio:
            return hasTouchID ? "id_touchid".localized : "id_faceid".localized
        case .pin:
            return "id_pin".localized
        case .genuineCheck:
            return "id_genuine_check".localized
        case .fwUpdate:
            return "id_firmware_update".localized
        case .recoveryPhrase:
            return "id_manual_backup".localized
        }
    }
    var hint: String {
        return ""
    }
    var icName: String {
        switch self.type {
        case .bio:
            return hasTouchID ? "touchid" : "faceid"
        case .pin:
            return "ic_onboard_mini_pin"
        case .genuineCheck:
            return "ic_preference_genuine_check"
        case .fwUpdate:
            return "ic_preference_fw_update"
        case .recoveryPhrase:
            return "ic_preference_recovery_phrase"
        }
    }
}
