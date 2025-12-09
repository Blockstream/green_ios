import UIKit

enum ActionCardType {
    case lightningTransfer
}

class ActionCell: UITableViewCell {
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var btnAction: UIButton!
    class var identifier: String { return String(describing: self) }
    var onAction: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func setStyle() {
        bg.setStyle(CardStyle.defaultStyle)
        btnAction.setStyle(.inline)
        lblInfo.setStyle(.txt)
    }
    func configure(model: ActionCellModel,
                   onAction: (() -> Void)?
    ) {
        switch model.type {
        case .lightningTransfer:
            self.lblInfo.text = "Your lightning account has onchain funds. Transfer to an onchain address to make them spendable again.".localized
            self.btnAction.setTitle("Transfer Funds".localized, for: .normal)
            self.onAction = onAction
        }
        setStyle()
    }
    @IBAction func btnAction(_ sender: Any) {
        onAction?()
    }
}
