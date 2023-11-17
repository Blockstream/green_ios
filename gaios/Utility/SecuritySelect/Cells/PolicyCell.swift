import UIKit

class PolicyCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var btnDisclose: UIButton!
    @IBOutlet weak var imgMS: UIImageView!
    @IBOutlet weak var imgSS: UIImageView!
    @IBOutlet weak var imgLight: UIImageView!
    @IBOutlet weak var lblType: UILabel!
    @IBOutlet weak var lblTypeDesc: UILabel!
    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var bgType: UIView!
    @IBOutlet weak var bgTypeDesc: UIView!
    @IBOutlet weak var imgBeta: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        bg.cornerRadius = 5.0
        btnDisclose.isUserInteractionEnabled = false
        btnDisclose.backgroundColor = UIColor.gGreenMatrix()
        btnDisclose.cornerRadius = 4.0
        bgType.cornerRadius = bgType.frame.size.height / 2.0
        bgTypeDesc.cornerRadius = bgType.frame.size.height / 2.0
        lblName.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        lblHint.setStyle(.txtCard)
        lblHint.textColor = UIColor.gW60()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {
        super.prepareForReuse()
        imgLight.isHidden = true
        imgBeta.isHidden = true
        [bgType, bgTypeDesc].forEach {
            $0?.backgroundColor = UIColor.gGrayBtn()
        }
        [lblType, lblTypeDesc].forEach {
            $0?.textColor = UIColor.gW60()
        }
    }

    func configure(model: PolicyCellModel) {
        imgSS.isHidden = !model.isSS
        imgMS.isHidden = model.isSS
        lblType.text = model.type.uppercased()
        lblTypeDesc.text = model.typeDesc.uppercased()
        lblName.text = model.name
        lblHint.text = model.hint
        imgBeta.isHidden = true
        if model.isLight == true {
            imgLight.isHidden = false
            imgBeta.isHidden = false
            imgSS.isHidden = true
            imgMS.isHidden = true
            lblTypeDesc.textColor = .white
            bgTypeDesc.backgroundColor = UIColor.gLightning()
        }
    }
}
