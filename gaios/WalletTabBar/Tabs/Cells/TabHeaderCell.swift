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

        walletsView.isHidden = true // hide for the moment
        btnTap.isHidden = true // hide for the moment
    }

    func configure(title: String, onTap: (() -> Void)?) {
        lblTitle.text = title
        lblWallet.text = AccountsRepository.shared.current?.name ?? ""
        self.onTap = onTap
    }
    @IBAction func btnTap(_ sender: Any) {
        walletsView.pressAnimate {
            self.onTap?()
        }
    }
}
