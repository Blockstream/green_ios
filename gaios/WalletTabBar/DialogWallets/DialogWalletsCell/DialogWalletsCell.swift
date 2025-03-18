import UIKit
import gdk
import core

class DialogWalletsCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var arrow: UIImageView!

    private var onTap: (() -> Void)?

    static var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        [lblName].forEach {
            $0?.setStyle(.txtBigger)
        }
        arrow.image = UIImage(systemName: "chevron.right")?.withTintColor(.white)
    }

    func configure(model: Account,
                   onTap: (() -> Void)?
    ) {
        self.onTap = onTap
        lblName.text = model.name
    }

    @IBAction func btnTap(_ sender: Any) {
        bg.pressAnimate {
            self.onTap?()
        }
    }
}
