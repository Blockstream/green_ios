import UIKit

class SendTitleView: UIView {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var icon: UIImageView!

    func configure(txt: String, icon: String) {
        lblTitle.text = txt
        self.icon.image = UIImage(named: icon)!
        lblTitle.setStyle(.txtBigger)
    }
    func configure(txt: String, image: UIImage) {
        lblTitle.text = txt
        self.icon.image = image
        lblTitle.setStyle(.txtBigger)
    }

}
