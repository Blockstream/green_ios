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
    @IBOutlet weak var disableView: UIView!
    @IBOutlet weak var lblDisableTitle: UILabel!
    @IBOutlet weak var lblDisableHint: UILabel!

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
        disableView.cornerRadius = 5.0
        lblDisableTitle.text = "id_added_already".localized
        lblDisableHint.text = "id_you_cannot_add_more_than_one".localized
        lblDisableTitle.setStyle(.txtBigger)
        [lblHint, lblDisableHint].forEach {
            $0.setStyle(.txtCard)
            $0.textColor = UIColor.gW60()
        }
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
        disableView.isHidden = true
        disableView.subviews.forEach {
            if let _ = $0 as? UIStackView { } else {
                $0.removeFromSuperview()
            }
        }
    }

    func configure(model: PolicyCellModel, hasLightning: Bool) {
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

            if hasLightning {
                self.disableView.cornerRadius = 5.0
                self.disableView.addSubview(self.blurredView)
                self.disableView.sendSubviewToBack(self.blurredView)
                self.disableView.isHidden = false
            }
        }
    }

    lazy var blurredView: UIView = {
        let frame = CGRect(x: 0.0, y: 0.0, width: UIScreen.main.bounds.width - 50, height: disableView.bounds.height)
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .dark)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.4)
        customBlurEffectView.frame = frame
        customBlurEffectView.layer.cornerRadius = 5.0
        customBlurEffectView.layer.masksToBounds = true
        let dimmedView = UIView()
        dimmedView.backgroundColor = .black.withAlphaComponent(0.1)
        dimmedView.frame = frame
        dimmedView.cornerRadius = 5.0
        containerView.addSubview(customBlurEffectView)
        containerView.addSubview(dimmedView)

        return containerView
    }()
}
