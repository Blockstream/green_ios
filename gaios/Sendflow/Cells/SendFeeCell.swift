import UIKit

class SendFeeCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var btnDisclose: UIButton!
    @IBOutlet weak var bgTopBox: UIView!

    @IBOutlet weak var lblSpeedName: UILabel!
    @IBOutlet weak var bgTime: UIView!
    @IBOutlet weak var lblTime: UILabel!

    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var lblRate: UILabel!
    @IBOutlet weak var lblFiat: UILabel!

    @IBOutlet weak var noFundsView: UIView!
    @IBOutlet weak var iconNoFunds: UIImageView!
    @IBOutlet weak var lblNoFunds: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        bg.cornerRadius = 4.0
        bgTopBox.cornerRadius = 4.0
        bgTopBox.backgroundColor = UIColor.gGrayElement()
        btnDisclose.isUserInteractionEnabled = false
        btnDisclose.cornerRadius = 4.0

        lblSpeedName.setStyle(.txtBigger)
        [lblAmount, lblRate, lblFiat].forEach {
            $0?.setStyle(.txtCard)
            $0?.textColor = .white.withAlphaComponent(0.7)
        }
        lblNoFunds.setStyle(.txt)
        iconNoFunds.image = UIImage(named: "ic_lightning_info")!.maskWithColor(color: .white)

        bgTime.cornerRadius = bgTime.frame.size.height / 2.0
        bgTime.borderWidth = 1.0
        bgTime.borderColor = .white.withAlphaComponent(0.3)
        lblNoFunds.text = ""
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    func configure(model: SendFeeCellModel) {
        if let error = model.error {
            bg.backgroundColor = UIColor.gRedWarn()
            btnDisclose.backgroundColor = UIColor.gW60()
            btnDisclose.alpha = 0.3
            lblNoFunds.text = error.localized
            noFundsView.isHidden = false
        } else {
            bg.backgroundColor = .clear
            btnDisclose.backgroundColor = UIColor.gGreenMatrix()
            btnDisclose.alpha = 1.0
            noFundsView.isHidden = true
        }
        lblSpeedName.text = model.speedName
        lblTime.text = model.time
        lblAmount.text = model.amount
        lblRate.text = model.rate
        lblFiat.text = model.fiat
    }
}
