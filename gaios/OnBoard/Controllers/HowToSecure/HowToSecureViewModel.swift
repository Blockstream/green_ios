import Foundation
import UIKit


enum HowToSecureViewModelType {
    
    case sw
    case hw
}

class HowToSecureViewModel {

    var items: [HowToSecureCellModel] {
        return [
            HowToSecureCellModel(type: .sw, title: "On This Device".localized, txt: "Your phone will store the keys to your bitcoin, PIN protected.".localized, hint: "For Ease of Use".localized, icon: UIImage(named: "ic_how_secure_sw")!),
            HowToSecureCellModel(type: .hw, title: "On Hardware Wallet".localized, txt: "Your keys will be secured on a dedicated cold storage device, PIN protected.".localized, hint: "For Higher Security".localized, icon: UIImage(named: "ic_how_secure_hw")!)
        ]
    }
}
