import UIKit

class DialogListCellModel: DialogCellModel {

    var type: DialogCellType
    var icon: UIImage?
    let title: String
    var hint: String?
    var switchState: Bool?

    init(type: DialogCellType,
         icon: UIImage?,
         title: String,
         hint: String? = nil,
         switchState: Bool? = nil) {
        self.type = type
        self.icon = icon
        self.title = title
        self.hint = hint
        self.switchState = switchState
    }
}
