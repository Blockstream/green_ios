import UIKit
import DGCharts

class SecurityLevelCell: UITableViewCell {

    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnCompare: UIButton!
    var onCompare: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    override func awakeFromNib() {
        super.awakeFromNib()
        btnCompare.setStyle(.primary)
        btnCompare.setTitle("Compare Security Levels".localized, for: .normal)
        btnCompare.setTitleColor(UIColor.gBlackBg(), for: .normal)
        lblHint.setStyle(.txtCard)
        lblTitle.setStyle(.subTitle24)
        lblHint.text = "Security Level".localized
        lblTitle.text = "Basic".localized
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(onCompare: (() -> Void)?) {
        self.onCompare = onCompare
    }

    @IBAction func btnOnCompare(_ sender: Any) {
        onCompare?()
    }
}
