import UIKit

class CoinSortCell: UITableViewCell {
    @IBOutlet weak var dividerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        dividerView.backgroundColor = .gBorderBold()
        titleLabel.setStyle(.txt)
        iconImageView.tintColor = .gAccent()
        iconImageView.image = iconImageView.image?.withRenderingMode(.alwaysTemplate)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title
        titleLabel.textColor = isSelected ? .gAccent() : .white
        iconImageView.alpha = isSelected ? 1.0 : 0.0
    }
}
