import UIKit

class TransactionInitRefundCell: UITableViewCell {

    @IBOutlet weak var btnInitRefund: UIButton!
    var action: (() -> ())?

    override func awakeFromNib() {
        super.awakeFromNib()

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(action: (() -> ())?) {
        btnInitRefund.setStyle(.primary)
        btnInitRefund.setTitle("Initiate Refund".localized, for: .normal)
        self.action = action
    }

    @IBAction func btnInitRefund(_ sender: Any) {
        action?()
    }
}
