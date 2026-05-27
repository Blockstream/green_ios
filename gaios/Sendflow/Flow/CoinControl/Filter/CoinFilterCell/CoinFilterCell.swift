import UIKit

class CoinFilterCell: UITableViewCell {
    @IBOutlet weak var background: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    class var identifier: String { return String(describing: self) }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        background.setStyle(.defaultStyle)
        titleLabel.setStyle(.txt)
        iconImageView.tintColor = .white
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func configure(iconImage: UIImage, title: String, isSelected: Bool) {
        background.borderColor = isSelected ? .gAccent() : .gBorderBold()
        background.backgroundColor = isSelected ? .gAccent().withAlphaComponent(0.1) : .gGrayCard()

        iconImageView.image = iconImage.withRenderingMode(.alwaysTemplate)
        titleLabel.text = title
    }
}
