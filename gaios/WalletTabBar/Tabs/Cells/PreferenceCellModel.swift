import Foundation
import UIKit

enum PreferenceCellState: String {
    case on = "ON"
    case off = "OFF"
    case unknown
}
enum PreferenceType {
    case faceID
    case pin
    case genuineCheck
    case fwUpdate
}
class PreferenceCellModel {
    var state: PreferenceCellState
    var type: PreferenceType

    init(preferenceType: PreferenceType,
         state: PreferenceCellState) {
        self.state = state
        self.type = preferenceType
    }
    var icImg: UIImage? {
        UIImage(named: icName)
    }
    var title: String {
        switch self.type {
        case .faceID:
            return "FaceID".localized
        case .pin:
            return "PIN".localized
        case .genuineCheck:
            return "Genuine Check".localized
        case .fwUpdate:
            return "Firmware Update".localized
        }
    }
    var hint: String {
        return ""
    }
    var icName: String {
        switch self.type {
        case .faceID:
            return "ic_onboard_mini_face"
        case .pin:
            return "ic_onboard_mini_pin"
        case .genuineCheck:
            return "ic_preference_genuine_check"
        case .fwUpdate:
            return "ic_preference_fw_update"
        }
    }
}
