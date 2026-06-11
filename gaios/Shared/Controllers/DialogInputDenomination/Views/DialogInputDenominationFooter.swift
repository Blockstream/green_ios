import UIKit

import core

class DialogInputDenominationFooter: UIView {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var icon: UIImageView!

    var onTap: (() -> Void)?

    func configure(title: String,
                   balance: Balance?,
                   isSelected: Bool,
                   onTap: (() -> Void)?
    ) {
        lblTitle.setStyle(.titleCard)
        lblHint.setStyle(.txtCard)
        lblTitle.text = title
        icon.isHidden = isSelected == false
        lblTitle.textColor = isSelected ? UIColor.gAccent() : .white
        self.onTap = onTap
        lblHint.text = ""
        if let balance {
            let converter = WalletManager.current?.converter
            lblHint.text = converter?.formatFiat(balance)
          }
    }

    @IBAction func btnFiat(_ sender: Any) {
        onTap?()
    }
}
