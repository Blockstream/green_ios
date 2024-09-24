import UIKit
import gdk
import core

class TxDetailsTotalsCell: UITableViewCell {

    @IBOutlet weak var lblSumFeeKey: UILabel!
    @IBOutlet weak var lblSumFeeValue: UILabel!
    @IBOutlet weak var lblSumAmountKey: UILabel!
    @IBOutlet weak var lblSumAmountValue: UILabel!
    @IBOutlet weak var lblSumTotalKey: UILabel!
    @IBOutlet weak var lblSumTotalValue: UILabel!
    @IBOutlet weak var lblConversion: UILabel!
    @IBOutlet weak var btnInfoFee: UIButton!

    class var identifier: String { return String(describing: self) }

    var model: TxDetailsTotalsCellModel?
    var onInfoFee: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()

        setContent()
        setStyle()
    }

    func configure(model: TxDetailsTotalsCellModel,
                   onInfoFee: (() -> Void)?) {
        self.model = model
        self.onInfoFee = onInfoFee

        lblSumFeeValue.text = model.ntwFees
        lblSumAmountValue.text = model.receive.replacingOccurrences(of: "-", with: "")
        lblSumTotalValue.text = model.totalSpent
        lblConversion.text = model.conversion

        if model.hideBalance {
            lblSumTotalValue.attributedText = Common.obfuscate(color: .white, size: 16, length: 5)
            [lblSumAmountValue, lblSumFeeValue, lblConversion].forEach {
                $0.attributedText =  Common.obfuscate(color: UIColor.gW40(), size: 10, length: 5)
            }
        }
    }

    func setContent() {
        lblSumFeeKey.text = "id_network_fee".localized
        lblSumAmountKey.text = "Recipient Receives".localized
        lblSumTotalKey.text = "id_total_spent".localized
    }

    func setStyle() {
        [lblSumFeeKey, lblSumFeeValue, lblSumAmountKey, lblSumAmountValue, lblConversion].forEach {
            $0?.setStyle(.txtCard)
        }
        [lblSumTotalKey, lblSumTotalValue].forEach {
            $0?.setStyle(.txtBigger)
        }
        btnInfoFee.setImage(UIImage(named: "ic_lightning_info_err")!.maskWithColor(color: UIColor.gW40()), for: .normal)
    }

    @IBAction func btnInfoFee(_ sender: Any) {
        onInfoFee?()
    }
}
