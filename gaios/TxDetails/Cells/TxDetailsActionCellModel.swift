import UIKit
import gdk

class TxDetailsActionCellModel {

    var icon: UIImage
    var title: String
    var action: TxDetailsAction
    
    init(icon: UIImage,
         title: String,
         action: TxDetailsAction
    ) {
        self.icon = icon
        self.title = title
        self.action = action
    }
}
