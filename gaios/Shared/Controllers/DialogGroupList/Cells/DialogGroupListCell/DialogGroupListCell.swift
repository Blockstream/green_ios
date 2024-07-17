import UIKit

class DialogGroupListCell: UITableViewCell {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var bgScore: UIView!
    @IBOutlet weak var lblScore: UILabel!

    var indexPath: IndexPath?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.txt)
        lblHint.setStyle(.txtSmaller)
        lblHint.textColor = .gW60()
        bgScore.cornerRadius = bgScore.frame.size.height / 2.0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: DialogGroupCellModel,
                   indexPath: IndexPath? = nil) {
        guard let model = model as? DialogGroupListCellModel else { return }
        self.indexPath = indexPath

        icon.isHidden = true
        if let img = model.icon {
            icon.image = img
            icon.isHidden = false
            if model.destructive == true {
                icon.image = icon.image?.maskWithColor(color: UIColor.gRedFluo())
            }
        }
        lblTitle.text = model.title
        if model.destructive == true {
            lblTitle.textColor = UIColor.gRedFluo()
        }
        lblHint.text = model.hint
        lblHint.isHidden = model.hint == nil
        separator.isHidden = true
        bgScore.isHidden = model.score == nil
        lblScore.text = "\(model.score ?? 0)"
    }
}
