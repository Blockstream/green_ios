import Foundation

import core

extension Settings {

    func getScreenLock() -> ScreenLockType {
        let wallet = WalletsStorage.shared.current
        if wallet?.hasBioPin ?? false && wallet?.hasManualPin ?? false {
            return .All
        } else if wallet?.hasBioPin ?? false {
            let biometryType = AuthenticationTypeHandler.biometryType
            return biometryType == .faceID ? .FaceID : .TouchID
        } else if wallet?.hasManualPin ?? false {
            return .Pin
        } else {
            return .None
        }
    }
}
