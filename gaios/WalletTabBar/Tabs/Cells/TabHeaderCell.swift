import UIKit

class TabHeaderCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.subTitle)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(title: String) {
        lblTitle.text = title
    }
}
