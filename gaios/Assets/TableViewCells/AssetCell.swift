import Foundation
import UIKit
import gdk
import core

class AssetCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var domainLabel: UILabel!
    @IBOutlet weak var amountTickerLabel: UILabel!
    @IBOutlet weak var assetIconImageView: UIImageView!
    @IBOutlet weak var bgView: UIView!

    private var btc: String {
        return WalletManager.current?.account.gdkNetwork.getFeeAsset() ?? ""
    }

    override func prepareForReuse() {
        nameLabel.text = ""
        domainLabel.text = ""
        amountTickerLabel.text = ""
        assetIconImageView.image = nil
    }

    func configure(tag: String, info: AssetInfo?, icon: UIImage?, satoshi: Int64, negative: Bool = false, isTransaction: Bool = false, sendAll: Bool = false) {
        if let balance = Balance.fromSatoshi(satoshi, assetId: info?.assetId ?? btc) {
            let (amount, denom) = balance.toValue()
            let amountTxt = sendAll ? "id_all".localized : amount
            amountTickerLabel.text = "\(negative ? "-": "")\(amountTxt) \(denom)"
        }
        selectionStyle = .none
        nameLabel.text = info?.name ?? tag
        domainLabel.text = info?.entity?.domain ?? ""
        domainLabel.isHidden = info?.entity?.domain.isEmpty ?? true
        assetIconImageView.image = icon
        self.backgroundColor = UIColor.customTitaniumDark()
        bgView.layer.cornerRadius = 6.0
    }
}
