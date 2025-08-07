import UIKit
import gdk

class TFAMethodCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var actionSwitch: UISwitch!
    @IBOutlet weak var maskedData: UILabel!

    var onActionSwitch: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBigger)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(_ item: TwoFactorItem, onActionSwitch: (() -> Void)? = nil) {
        self.lblTitle.text = item.name
        self.actionSwitch.isOn = item.enabled
        self.actionSwitch.isUserInteractionEnabled = false
        self.onActionSwitch = onActionSwitch
        if let data = item.maskedData, item.confirmed == true {
            self.maskedData.text = data
        } else {
            self.maskedData.text = ""
        }
    }
    @IBAction func actionSwitchChanged(_ sender: Any) {
        onActionSwitch?()
    }
}
