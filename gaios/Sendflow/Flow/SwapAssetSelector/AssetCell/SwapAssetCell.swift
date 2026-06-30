import UIKit
import core

class SwapAssetCell: UITableViewCell {
    @IBOutlet weak var cardBgView: UIView!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var caretView: UIImageView!
    
    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        cardBgView.setStyle(.defaultStyle)
        nameLabel.setStyle(.titleCard)
        nameLabel.font = UIFont.systemFont(ofSize: nameLabel.font.pointSize, weight: .medium)
        caretView.tintColor = .white
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func configure(with model: SwapAssetCellModel) {
        iconView.image = model.icon
        nameLabel.text = model.title
    }
}
