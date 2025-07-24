import UIKit
import DGCharts

class WatchonlyCell: UITableViewCell {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    var onLearnMore: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    let strWo = "In a watch-only wallet, you don’t have access to the private keys, so you can’t send funds - you can only view your balance and transaction history. Learn more about watch-only."
    let strSend = "you can’t send funds".localized
    let strMore = "Learn more".localized

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.title)
        lblTitle.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        lblHint.setStyle(.txtCard)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(onLearnMore: (() -> Void)?) {
        self.onLearnMore = onLearnMore
        lblTitle.text = "Watch-Only".localized
        setStyle()
    }
    func setStyle() {

        let pStyle = NSMutableParagraphStyle()
        pStyle.lineSpacing = 2.0
        let linkAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gAccent(),
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let boldAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 16, weight: .medium)
        ]
        let attrStr = NSMutableAttributedString(string: strWo)
        attrStr.addAttribute (
            NSAttributedString.Key.paragraphStyle,
            value: pStyle,
            range: NSRange(location: 0, length: attrStr.length))
        attrStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 16, weight: .regular), range: NSRange(location: 0, length: attrStr.length))
        attrStr.setAttributes(boldAttr, for: strSend)
        attrStr.setAttributes(linkAttr, for: strMore)
        lblHint.attributedText = attrStr
        lblHint.isUserInteractionEnabled = true
        lblHint.lineBreakMode = .byWordWrapping
        lblHint.textAlignment = .center
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(onTap(_:)))
        tapGesture.numberOfTouchesRequired = 1
        lblHint.addGestureRecognizer(tapGesture)
    }
    @objc func onTap(_ sender: Any?) {
        onLearnMore?()
    }
}
