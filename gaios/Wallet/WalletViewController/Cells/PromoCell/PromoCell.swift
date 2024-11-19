import AVFoundation
import UIKit
import gdk
import core

enum PromoType {
    case jadeDiscount
}

class PromoCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnAction: UIButton!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var iconWrap: UIView!

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

        lblTitle.text = model.promo.title_small?.htmlDecoded
        lblHint.text = model.promo.text_small?.htmlDecoded
        btnAction.setTitle(model.promo.cta_small?.htmlDecoded, for: .normal)

        if let thumb = model.promo.thumb {
            let w = thumb.size.width
            let h = thumb.size.height
            if h > 0 {
                let nW = 100 * w / h
                let resized = thumb.resize(Int(nW), 100)
                iconWrap.isHidden = false
                icon.image = resized
            }
        } else {
            iconWrap.isHidden = true
        }
    }

    func setStyle() {
        bg.layer.cornerRadius = 6.0
        bg.borderWidth = 1.0
        bg.borderColor = .white.withAlphaComponent(0.1)
        lblTitle.setStyle(.subTitle)
        lblTitle.font = UIFont.systemFont(ofSize: 20.0, weight: .semibold)
        lblHint.setStyle(.txtCard)
        btnAction.setStyle(.primary)
        btnDismiss.setImage(UIImage(named: "cancel")?.maskWithColor(color: .white), for: .normal)
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

public extension UIImage {

    func resize(_ width: Int, _ height: Int) -> UIImage {
        let maxSize = CGSize(width: width, height: height)
        let availableRect = AVFoundation.AVMakeRect(
            aspectRatio: self.size,
            insideRect: .init(origin: .zero, size: maxSize)
        )
        let targetSize = availableRect.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized
    }
}
