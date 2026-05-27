import UIKit
import core

class CoinDetailsRowCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueView: UIView!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setStyle(.txtCard)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        valueView.subviews.forEach { $0.removeFromSuperview() }
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        self.contentView.bounds.size.width = targetSize.width
        self.contentView.layoutIfNeeded()

        if let label = valueView.subviews.first as? UILabel, label.numberOfLines == 0 {
            if label.frame.width > 0 {
                label.preferredMaxLayoutWidth = label.frame.width
            }
        }

        return super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority, verticalFittingPriority: verticalFittingPriority)
    }

    func configure(title: String, view: UIView) {
        titleLabel.text = title
        
        valueView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: valueView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: valueView.trailingAnchor),
            view.topAnchor.constraint(equalTo: valueView.topAnchor),
            view.bottomAnchor.constraint(equalTo: valueView.bottomAnchor)
        ])
    }
}
