import UIKit
import gdk

class TFATimeCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var imgRadio: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBigger)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(item: CsvTime, current: Int?, gdkNetwork: GdkNetwork) {
        self.lblTitle.text = item.shortLabel()
        let isSelected = current == item.value(for: gdkNetwork)
        imgRadio.image = isSelected ? UIImage(named: "ic_toggle_on") : UIImage(named: "ic_toggle_off")
    }
}
