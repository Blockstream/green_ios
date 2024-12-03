import UIKit

class JadeDeviceCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var btnDisclose: UIButton!
    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var iconSensor: UIImageView!
    @IBOutlet weak var lblBlockstream: UILabel!
    @IBOutlet weak var jadeImg: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        bg.cornerRadius = 5.0
        btnDisclose.isUserInteractionEnabled = false
        btnDisclose.backgroundColor = UIColor.gGreenMatrix()
        btnDisclose.cornerRadius = 4.0
        lblBlockstream.text = "Blockstream"
        iconSensor.image = iconSensor.image?.maskWithColor(color: .white)
        jadeImg.image = JadeAsset.img(.normalDual, nil)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    func configure(text: String) {

        lblName.text = text
        setStyle()
    }

    func setStyle() {
        lblName.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        lblName.textColor = .white
    }
}
