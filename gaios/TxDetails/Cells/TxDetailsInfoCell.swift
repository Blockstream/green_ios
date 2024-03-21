import UIKit

class TxDetailsInfoCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    
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
    }

    func configure(model: TxDetailsInfoCellModel, onTap: ((String)->Void)?) {
        self.lblTitle.text = model.title
        self.lblHint.text = model.hint
        self.model = model
        self.onTap = onTap
        if model.type == .address {
            
            let attributedHint = NSMutableAttributedString(string: model.hint)
            attributedHint.addAttribute(.foregroundColor, value: UIColor.gGreenMatrix(), range: NSRange(location: 0, length: 6))
            attributedHint.addAttribute(.foregroundColor, value: UIColor.gGreenMatrix(), range: NSRange(location: model.hint.count - 6, length: 6))
            lblHint.attributedText = attributedHint
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
