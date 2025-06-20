import UIKit
import gdk

class DialogInputDenominationCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var icon: UIImageView!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.titleCard)
        lblHint.setStyle(.txtCard)
        icon.image = UIImage(named: "ic_check_circle")?.maskWithColor(color: UIColor.gAccent())
    }

    override func prepareForReuse() {
        lblTitle.text = ""
        lblHint.text = ""
        icon.isHidden = true
    }

    func configure(denomination: DenominationType,
                   balance: Balance?,
                   network: NetworkSecurityCase,
                   isSelected: Bool) {
        lblTitle.text = self.symbol(denomination, network)
        icon.isHidden = isSelected == false
        lblTitle.textColor = isSelected ? UIColor.gAccent() : .white
        var hint = ""
        guard let balance = balance else {
            lblHint.text = ""
            return
        }

        switch denomination {
        case .BTC:
            hint = balance.btc
        case .MilliBTC:
            hint = balance.mbtc
        case .MicroBTC, .Bits:
            hint = balance.bits
        case .Sats:
            hint = balance.sats
        }
        lblHint.text = "\(hint) \(self.symbol(denomination, network))"
    }

    func symbol(_ denom: DenominationType, _ network: NetworkSecurityCase) -> String {
        return denom.string(for: network.gdkNetwork)
    }
}
