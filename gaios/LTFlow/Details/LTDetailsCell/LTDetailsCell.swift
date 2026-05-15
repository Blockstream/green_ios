import UIKit

class LTDetailsCell: UITableViewCell {
    
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblValue: UILabel!

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.titleCard)
        lblValue.setStyle(.txtCard)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: LTDetailsCellModel) {
        self.lblTitle.text = model.title
        self.lblValue.text = model.value
    }
}
