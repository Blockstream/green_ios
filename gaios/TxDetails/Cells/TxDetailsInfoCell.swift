import UIKit

class TxDetailsInfoCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var addressTextView: UITextView!
    @IBOutlet weak var innerPad: UIView!

    class var identifier: String { return String(describing: self) }

    var model: TxDetailsInfoCellModel?

    var onTap: ((String) -> Void)?

    override func prepareForReuse() {
        lblTitle.text = ""
        lblHint.text = ""
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        lblTitle.setStyle(.txtCard)
        lblHint.setStyle(.txt)
        addressTextView.isHidden = true
    }

    func configure(model: TxDetailsInfoCellModel, onTap: ((String)->Void)?) {
        self.lblTitle.text = model.title
        self.lblHint.text = model.hint

        self.model = model
        self.onTap = onTap
        if model.type == .address {
            lblHint.isHidden = true
            addressTextView.isHidden = false
            innerPad.isHidden = true
            AddressDisplay.configure(
                address: model.hint,
                textView: addressTextView,
                style: .txDetails)
        } else {
            addressTextView.isHidden = true
            lblHint.isHidden = false
            innerPad.isHidden = false
        }
        switch model.type {
        case .fee, .feeRate:
            if model.hideBalance {
                self.lblHint.attributedText = Common.obfuscate(color: .white, size: 12, length: 5)
            }
        default:
            break
        }
    }

    @IBAction func btnTap(_ sender: Any) {
        guard let hint = model?.hint else { return }
        onTap?(hint)
    }

}
