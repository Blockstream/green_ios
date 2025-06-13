import UIKit
import gdk

class SelectProviderCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var iconView: UIView!
    @IBOutlet weak var lblIcon: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblReceive: UILabel!
    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var bestView: UIView!
    @IBOutlet weak var lblBest: UILabel!
    var onTap: (() -> Void)?
    var model: SelectProviderCellModel?
    static var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.lightStyle)
        iconView.cornerRadius = 15.0
        lblIcon.setStyle(.txtBold)
        lblTitle.setStyle(.txtBold)
        bestView.cornerRadius = 11
        lblBest.setStyle(.txtSmallerBold)
        lblBest.textColor = UIColor.gBlackBg()
        bg.borderWidth = 1.0
        lblReceive.setStyle(.txtCard)
        lblAmount.setStyle(.txtBold)
    }
    override func prepareForReuse() {
        bestView.isHidden = true
        bg.borderColor = .white.withAlphaComponent(0.07)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: SelectProviderCellModel,
                   isBest: Bool = false,
                   onTap: (() -> Void)?) {
        self.model = model
        let pName = model.quote.serviceProvider
        self.lblTitle.text = pName
        let initials = getInitials(from: pName)
        lblIcon.text = initials
        iconView.backgroundColor = colorFromProviderName(pName)
        self.onTap = onTap
        lblBest.text = "Best Price"
        if isBest {
            bestView.isHidden = false
            bg.borderColor = UIColor.gAccent()
        } else {
            bestView.isHidden = true
            bg.borderColor = .white.withAlphaComponent(0.07)
        }
        lblReceive.text = "id_you_receive".localized
        lblAmount.text = String(format: "%.8f BTC", model.quote.destinationAmount)
    }
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count > 1 {
            let first = components[0].prefix(1)
            let second = components[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else if !name.isEmpty {
            return String(name.prefix(2)).uppercased()
        }
        return "--"
    }
    private func colorFromProviderName(_ name: String) -> UIColor {
        let hash = abs(name.hashValue)
        let hue = CGFloat(hash % 360) / 360.0
        return UIColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0)
    }
    @IBAction func didTap(_ sender: Any) {
        bg.pressAnimate {
            self.onTap?()
        }
    }
}
