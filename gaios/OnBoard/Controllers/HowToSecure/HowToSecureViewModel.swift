import Foundation
import UIKit

enum HowToSecureViewModelType {
    case sw
    case hw
}

class HowToSecureViewModel {

    var items: [HowToSecureCellModel] {
        return [
            HowToSecureCellModel(type: .sw, title: "id_on_this_device".localized, txt: "id_your_phone_will_store_the_keys".localized, hint: "id_for_ease_of_use".localized, icon: UIImage(named: "ic_how_secure_sw")!),
            HowToSecureCellModel(type: .hw, title: "id_on_hardware_wallet".localized, txt: "id_your_keys_will_be_secured_on_a".localized, hint: "id_for_higher_security".localized, icon: JadeAsset.img(.secure, nil))
        ]
    }
}
