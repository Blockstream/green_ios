import UIKit

class SwapFeeCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var btnDisclose: UIButton!
    @IBOutlet weak var lblSpeedName: UILabel!
    @IBOutlet weak var lblTime: UILabel!
    @IBOutlet weak var lblRate: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 4.0
        btnDisclose.isUserInteractionEnabled = false
        [lblSpeedName, lblRate].forEach {
            $0?.setStyle(.txtBigger)
        }
        lblTime.setStyle(.txtCard)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    func configure(model: SwapFeeCellModel) {
        lblSpeedName.text = model.speedName
        lblTime.text = model.time
        lblRate.text = String(format: "%.2f sats/vB", Double(model.feeRate ?? 0) / 1000.0)
    }
}
