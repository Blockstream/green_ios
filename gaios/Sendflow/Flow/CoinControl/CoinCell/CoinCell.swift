import UIKit
import core

class CoinCell: UITableViewCell {
    @IBOutlet weak var background: UIView!
    @IBOutlet weak var selectedImageView: UIImageView!
    @IBOutlet weak var hashLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountFiatLabel: UILabel!
    @IBOutlet weak var infoButton: UIButton!

    var onInfoTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        background.setStyle(.defaultStyle)
        [hashLabel, amountLabel].forEach {
            $0.setStyle(.txt)
            $0.font = UIFont.systemFont(ofSize: $0.font.pointSize, weight: .semibold)
        }
        [statusLabel, amountFiatLabel].forEach {
            $0.setStyle(.txtSmaller)
            $0.textColor = .gGrayTxt()
        }
        
        infoButton.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)
    }

    @objc private func infoButtonTapped() {
        onInfoTapped?()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    class var identifier: String { return String(describing: self) }
    
    func configure(_ utxo: UnspentOutput, isSelected: Bool, denomination: DenominationType? = nil, isFiat: Bool = false) {
        let utxoHash = utxo.txhash ?? ""
        selectedImageView.image = isSelected ? UIImage(resource: .icCheckboxOn) : UIImage(resource: .icCheckboxOff)
        selectedImageView.alpha = isSelected ? 1 : 0.1
        hashLabel.text = "\(utxoHash.prefix(4))...\(utxoHash.suffix(4)):\(utxo.ptIdx ?? 0)"
        statusLabel.text = utxo.isUnconfirmed ? "Unconfirmed" : "Confirmed"
        let satoshi = utxo.satoshi ?? 0
        let assetId = utxo.assetId ?? "btc"
        
        let btcText = Balance.fromSatoshi(satoshi, assetId: assetId)?.toText(denomination)
        let fiatText = Balance.fromSatoshi(satoshi, assetId: assetId)?.toFiatText()
        
        amountLabel.text = isFiat ? fiatText : btcText
        amountFiatLabel.text = fiatText
    }
}
