import Foundation
import UIKit

class TabSettingsCellModel {

    var title: String
    var subtitle: String
    var attributed: NSAttributedString?
    var disclosure: Bool = false
    var disclosureImage: UIImage?
    var switcher: Bool?
    var type: SettingsItem?

    init(_ item: SettingsItemData) {
        title = item.title
        subtitle = item.subtitle
        attributed = item.attributed
        type = item.type
        switcher = item.switcher
        switch type {
        case .version, .supportID:
            disclosure = false
        default:
            disclosureImage = UIImage(named: "rightArrow")!
            disclosure = true
        }
    }
}
