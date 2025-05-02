import UIKit
import core

class TabHeaderCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var walletsView: UIView!
    @IBOutlet weak var lblWallet: UILabel!
    @IBOutlet weak var iconBox: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var btnTap: UIButton!

    var onTap: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.subTitle)
        lblWallet.setStyle(.txtCard)
        iconBox.layer.cornerRadius = iconBox.frame.size.width / 2
        iconBox.backgroundColor = UIColor.gAccent()
    }

    func configure(title: String, icon: UIImage, onTap: (() -> Void)?) {
        let attrText = NSAttributedString(string: AccountsRepository.shared.current?.name ?? "", attributes: [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.thick.rawValue, NSAttributedString.Key.foregroundColor: UIColor.gAccent()])
        lblTitle.text = title
        lblWallet.attributedText = attrText
        self.onTap = onTap
        self.icon.image = icon.maskWithColor(color: UIColor.gBlackBg())
    }
    @IBAction func btnTap(_ sender: Any) {
        walletsView.pressAnimate {
            self.onTap?()
        }
    }
}
