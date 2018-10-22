import Foundation
import UIKit

class WalletTableCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        // Initialization code
    }

    @IBOutlet var balance: UILabel!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var mainContent: UIView!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
