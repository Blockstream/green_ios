import UIKit
import gdk

class TFAEmptyCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtCard)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(isLiquid: Bool) {

        if isLiquid {
            lblTitle.text = "id_you_dont_have_any_liquid_2fa".localized
            lblHint.text = "id_create_a_liquid_2fa_protected".localized
        } else {
            lblTitle.text = "id_you_dont_have_any_bitcoin_2fa".localized
            lblHint.text = "id_create_a_bitcoin_2fa_protected".localized
        }
    }
}
