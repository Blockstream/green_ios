import UIKit

import core

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
        guard let balance = balance else {
            lblHint.text = ""
            return
        }
        let converter = WalletManager.current?.converter
        lblHint.text = converter?.formatBTC(balance, denomination: denomination)
    }

    func symbol(_ denom: DenominationType, _ network: NetworkSecurityCase) -> String {
        return denom.string(for: network.gdkNetwork)
    }
}
