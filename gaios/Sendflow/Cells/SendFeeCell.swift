import UIKit

class SendFeeCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var btnSelect: UIButton!
    @IBOutlet weak var bgTopBox: UIView!

    @IBOutlet weak var lblSpeedName: UILabel!
    @IBOutlet weak var bgTime: UIView!
    @IBOutlet weak var lblTime: UILabel!

    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var lblRate: UILabel!
    @IBOutlet weak var lblFiat: UILabel!

    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var iconError: UIImageView!
    @IBOutlet weak var lblError: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        bg.setStyle(.defaultStyle)
        bgTopBox.setStyle(.defaultStyle)

        bgTime.backgroundColor = .gGrayCardBorder()
        bgTime.cornerRadius = bgTime.frame.size.height / 2.0

        [lblSpeedName, lblAmount].forEach {
            $0.setStyle(.txt)
            $0.font = UIFont.systemFont(ofSize: $0.font.pointSize, weight: .semibold)
        }

        [lblRate, lblFiat].forEach {
            $0?.setStyle(.txtSmaller)
            $0?.textColor = .gGrayTxt()
        }

        lblError.setStyle(.txtSmaller)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    class var identifier: String { return String(describing: self) }

    func configure(model: SendFeeCellModel) {
        if let error = model.error {
            bg.backgroundColor = .gRedWarn()
            bg.borderColor = .gRedSwapErr2()
            bgTopBox.borderColor = .gRedSwapErr2()
            btnSelect.tintColor = .gGrayTxtDisabled()
            lblError.text = error
            errorView.isHidden = false
        } else {
            bg.backgroundColor = .clear
            bg.borderColor = .clear
            bgTopBox.borderColor = .gGrayCardBorder()
            btnSelect.tintColor = .white
            errorView.isHidden = true
        }
        lblSpeedName.text = model.speedName
        lblTime.text = model.time
        lblAmount.text = model.amount
        lblRate.text = model.rate
        lblFiat.text = model.fiat
    }
}
