import Foundation
import UIKit

enum PreferenceCellState: String {
    case on = "ON"
    case off = "OFF"
}
enum PreferenceType {
    case faceID
    case pin
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
        }
    }
    var hint: String {
        switch self.type {
        case .faceID:
            return ""
        case .pin:
            return ""
        }
    }
    var icName: String {
        switch self.type {
        case .faceID:
            return "ic_onboard_mini_face"
        case .pin:
            return "ic_onboard_mini_pin"
        }
    }
}
