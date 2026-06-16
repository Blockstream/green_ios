import Foundation
import hw
import UIKit

struct GenuineCheckDialogViewModel {
    let BleHwManager: BleHwManager?
    let board: JadeBoardType
    
    var jadeImage: UIImage? {
        let suffix = (board == .v2c) ? "_v2c" : "_v2"
        return UIImage(named: "il_genuine_check_connected\(suffix)")
    }
}
