import Foundation
import UIKit

class SettingsCell: UITableViewCell {


    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    var item: SettingsItem?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
}
