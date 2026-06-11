import UIKit

import core

class TxDetailsTotalsCell: UITableViewCell {

    @IBOutlet weak var lblSumFeeKey: UILabel!
    @IBOutlet weak var lblSumFeeValue: UILabel!
    @IBOutlet weak var lblSumFeeFiat: UILabel!
    @IBOutlet weak var lblSumTotalKey: UILabel!
    @IBOutlet weak var lblSumTotalValue: UILabel!
    @IBOutlet weak var lblConversion: UILabel!
    @IBOutlet weak var btnInfoFee: UIButton!
    @IBOutlet weak var totalLine: UIView!

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
        lblSumTotalValue.text = model.totalSpent
        lblSumFeeFiat.text = model.ntwFeesFiat
        lblConversion.text = "≈ " + model.conversion
        lblConversion.isHidden = !AssetInfo.baseIds.contains(model.assetId)

        if model.hideBalance {
            lblSumTotalValue.attributedText = Common.obfuscate(color: .white, size: 16, length: 5)
            [lblSumFeeFiat, lblSumFeeValue, lblConversion].forEach {
                $0.attributedText =  Common.obfuscate(color: UIColor.gW40(), size: 10, length: 5)
            }
        }
        if model.conversion.isEmpty {
            totalLine.isHidden = true
            [lblSumFeeKey, lblSumFeeValue].forEach {
                $0?.setStyle(.txtBigger)
            }
        }
    }

    func setContent() {
        lblSumFeeKey.text = "Total Fees".localized
        lblSumTotalKey.text = "id_total_spent".localized
    }

    func setStyle() {
        [lblSumFeeKey, lblSumFeeFiat, lblSumFeeValue, lblConversion].forEach {
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
