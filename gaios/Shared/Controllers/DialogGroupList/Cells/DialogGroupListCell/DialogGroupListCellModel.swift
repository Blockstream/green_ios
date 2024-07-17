import UIKit

class DialogGroupListCellModel: DialogGroupCellModel {

    var type: DialogGroupCellType
    var icon: UIImage?
    let title: String
    let destructive: Bool?
    let score: Int?
    var hint: String?

    init(type: DialogGroupCellType,
         icon: UIImage?,
         title: String,
         destructive: Bool? = false,
         score: Int?,
         hint: String? = nil) {
        self.type = type
        self.icon = icon
        self.title = title
        self.destructive = destructive
        self.score = score
        self.hint = hint
    }
}
