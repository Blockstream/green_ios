import UIKit
import gdk
import core

class AccountArchiveCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var lblType: UILabel!
    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var lblFiat: UILabel!
    @IBOutlet weak var icon: UIImageView!
    private var hideBalance: Bool = false

    private var onTap: (() -> Void)?

    static var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        bg.borderColor = .white.withAlphaComponent(0.1)
        [lblName, lblAmount].forEach {
            $0?.setStyle(.txtBigger)
        }
        [lblType, lblFiat].forEach {
            $0?.setStyle(.txtCard)
        }
        lblAmount.textColor = UIColor.gAccent()
    }

    func configure(model: AccountArchiveCellModel,
                   hideBalance: Bool,
                   isSelected: Bool,
                   onTap: (() -> Void)?
    ) {
        self.hideBalance = hideBalance
        self.onTap = onTap
        lblType.text = model.lblType
        lblName.text = model.name.localized

        if hideBalance {
            lblFiat.attributedText = Common.obfuscate(color: UIColor.gGrayTxt(), size: 12, length: 5)
            lblAmount.attributedText = Common.obfuscate(color: .white, size: 16, length: 5)
        } else {
            lblFiat.text = model.fiatStr ?? ""
            lblAmount.text = model.balanceStr ?? ""
        }
        icon.image =  isSelected ? UIImage(named: "ic_toggle_on") : UIImage(named: "ic_toggle_off")
    }
    @IBAction func btnTap(_ sender: Any) {
            bg.pressAnimate {
                self.onTap?()
            }
    }
}
