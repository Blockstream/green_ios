import Foundation
import UIKit

class TabSettingsCellModel {

    var title: String
    var icon: UIImage?
    var subtitle: String
    var attributed: NSAttributedString?
    var type: SettingsItem?

    init(_ item: SettingsItemData) {
        title = item.title
        icon = item.icon
        subtitle = item.subtitle
        attributed = item.attributed
        type = item.type

        switch type {
        case .version:
            icon = nil
        default:
            if icon == nil {
                icon = UIImage(named: "rightArrow")!
            }
        }
    }
}
