import UIKit

class DeviceCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var imgDisclosure: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var imgIcon: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBold)
        lblSubtitle.setStyle(.txtCard)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    func configure(text: String) {
        lblTitle.text = text
        lblSubtitle.text = "id_found_via_bluetooth".localized
    }
}
