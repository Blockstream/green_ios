import UIKit

protocol LTRecoverFundsFeeDelegate: AnyObject {
    func didChange(feeSliderIndex: Int)
}

class LTRecoverFundsFeeCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblFeeAmount: UILabel!
    @IBOutlet weak var lblGlobalFeeAmount: UILabel!
    @IBOutlet weak var lblGlobalFeeFiatAmount: UILabel!
    @IBOutlet weak var feeSlider: UISlider!

    class var identifier: String { return String(describing: self) }
    var feeSliderMaxIndex: Int = 3
    var delegate: LTRecoverFundsFeeDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        [lblFeeAmount].forEach {
            $0?.setStyle(.txtCard)
        }
    }

    override func prepareForReuse() {
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(fee: String, fiatFee: String, feeRate: String, feeSliderIndex: Int, feeSliderMaxIndex: Int = 3) {
        lblGlobalFeeAmount.text = fee
        lblGlobalFeeFiatAmount.text = fiatFee
        lblFeeAmount.text = feeRate
        self.feeSliderMaxIndex = feeSliderMaxIndex
        setFeeSlider(feeSliderIndex)
    }

    func setFeeSlider(_ index: Int) {
        feeSlider.value = Float(index)
    }

    @IBAction func didValueChange(_ sender: UISlider) {
        let index = Int(sender.value)
        setFeeSlider(index)
        delegate?.didChange(feeSliderIndex: index)
    }
}
