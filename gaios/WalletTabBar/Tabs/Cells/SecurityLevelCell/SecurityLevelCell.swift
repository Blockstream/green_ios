import UIKit
import DGCharts

class SecurityLevelCell: UITableViewCell {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var iconPlus: UIImageView!
    @IBOutlet weak var lblHint1: UILabel!
    @IBOutlet weak var lblHint2: UILabel!
    @IBOutlet weak var btnCompare: UIButton!
    var onCompare: (() -> Void)?
    var isHW = false

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    override func awakeFromNib() {
        super.awakeFromNib()
        btnCompare.setStyle(.outlined)
        btnCompare.setTitle("Compare Security Levels".localized, for: .normal)
        lblHint1.setStyle(.title)
        lblHint1.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        lblHint2.setStyle(.txtCard)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func setContent() {
        if isHW {
            lblHint1.text = "Hardware".localized
            lblHint2.text = "Security Level: 2".localized
            icon.isHidden = true
            iconPlus.isHidden = false
            btnCompare.isHidden = true
        } else {
            lblHint1.text = "Mobile".localized
            lblHint2.text = "Security Level: 1".localized
            icon.isHidden = false
            iconPlus.isHidden = true
            btnCompare.isHidden = false
        }
    }
    func configure(isHW: Bool, onCompare: (() -> Void)?) {
        self.isHW = isHW
        self.onCompare = onCompare
        setContent()
    }

    @IBAction func btnOnCompare(_ sender: Any) {
        onCompare?()
    }
}
