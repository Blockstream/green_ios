import AVFoundation
import UIKit
import gdk
import core

class PromoLayout2Cell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnAction: UIButton!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var gradient: UIView!

    var model: PromoCellModel?
    var onAction: (() -> Void)?
    var onDismiss: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        setStyle()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func prepareForReuse() {
        lblTitle.text = ""
        lblHint.text = ""
    }

    func configure(_ model: PromoCellModel,
                   onAction: (() -> Void)?,
                   onDismiss: (() -> Void)?
    ) {
        self.backgroundColor = UIColor.customTitaniumDark()
        self.model = model
        self.onAction = onAction
        self.onDismiss = onDismiss

        lblInfo.text = model.promo.overline_small
        lblTitle.text = model.promo.title_small
        lblHint.text = model.promo.text_small
        btnAction.setTitle(model.promo.cta_small, for: .normal)

        self.icon.image = model.promo.thumb
        if let thumb = model.promo.thumb {
            let w = thumb.size.width
            let h = thumb.size.height
            if w > 0 {
                let nW = (UIScreen.main.bounds.width - 50)
                let nH = nW * h / w
                let resized = thumb.resize(Int(nW), Int(nH))
                icon.image = resized
            }
        }
        // icon.clipsToBounds = true
    }

    func setStyle() {
        bg.layer.cornerRadius = 6.0
        bg.borderWidth = 1.0
        bg.borderColor = .white.withAlphaComponent(0.1)
        lblInfo.setStyle(.txtSmaller)
        lblTitle.setStyle(.subTitle24)
        lblHint.setStyle(.txtSmaller)
        btnAction.setStyle(.primary)
        btnDismiss.setImage(UIImage(named: "cancel")?.maskWithColor(color: .white), for: .normal)
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

//        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
//            let gLayer = self.makeGradient(colours: [.clear, .black.withAlphaComponent(0.5)], locations: [0.5, 1.0])
//            gLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
//            gLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
//            gLayer.frame = self.gradient.bounds
//            gLayer.masksToBounds = true
//            self.gradient.layer.addSublayer(gLayer)
//        }
    }

    @IBAction func btnAction(_ sender: Any) {
        onAction?()
    }

    @IBAction func onDismiss(_ sender: Any) {
        if let promo = model?.promo, let source = model?.source {
            PromoManager.shared.onDismiss(promo: promo, source: source)
        }
        onDismiss?()
    }
}
