import UIKit

class TFAActionsCell: UITableViewCell {

    @IBOutlet weak var btnRecoveryTool: UIButton!
    @IBOutlet weak var btnRecoveryTransactions: UIButton!
    var onRecTool: (() -> Void)?
    var onRecTxs: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        btnRecoveryTool.setStyle(.primary)
        btnRecoveryTransactions.setStyle(.outlined)
        btnRecoveryTool.setTitle("id_recovery_tool".localized, for: .normal)
        btnRecoveryTransactions.setTitle("id_recovery_transactions".localized, for: .normal)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure( onRecTool: (() -> Void)?,
                    onRecTxs: (() -> Void)?) {
        self.onRecTool = onRecTool
        self.onRecTxs = onRecTxs
    }
    @IBAction func btnRecoveryTool(_ sender: Any) {
        onRecTool?()
    }
    @IBAction func btnRecoveryTransactions(_ sender: Any) {
        onRecTxs?()
    }
}
