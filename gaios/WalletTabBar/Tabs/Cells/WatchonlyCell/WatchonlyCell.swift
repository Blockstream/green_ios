import UIKit
import DGCharts

class WatchonlyCell: UITableViewCell {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnLearnMore: UIButton!
    var onLearnMore: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.title)
        lblTitle.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        lblHint.setStyle(.txtCard)
        btnLearnMore.setStyle(.inline)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(onLearnMore: (() -> Void)?) {
        self.onLearnMore = onLearnMore
        lblTitle.text = "id_watchonly".localized
        lblHint.text = "id_in_a_watchonly_wallet_your".localized
        btnLearnMore.setTitle("id_learn_more".localized, for: .normal)
    }
    @IBAction func btnLearnMore(_ sender: Any) {
        onLearnMore?()
    }
}
