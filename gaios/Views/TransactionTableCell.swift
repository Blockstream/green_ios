import Foundation
import UIKit

class TransactionTableCell: UITableViewCell {

    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var address: UILabel!
    @IBOutlet weak var amount: UILabel!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var replaceable: UILabel!

    override func layoutSubviews() {
        replaceable.layer.masksToBounds = true
        replaceable.layer.cornerRadius = 4
        replaceable.layer.borderWidth = 1
        replaceable.layer.borderColor = UIColor.customTitaniumMedium().cgColor
        replaceable.text = "  " + NSLocalizedString("id_replaceable", comment: "").uppercased() + "  "
    }
}
