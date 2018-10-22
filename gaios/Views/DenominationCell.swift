import Foundation
import UIKit

class DenominationCell: UITableViewCell {

    var item: SettingsItem?
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
}
