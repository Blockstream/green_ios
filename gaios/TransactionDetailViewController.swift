import Foundation
import UIKit

class TransactionDetailViewController: UIViewController {


    @IBOutlet weak var hashLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var warniniglabel: UILabel!
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var feeButton: UIButton!
    @IBOutlet weak var bottomLabel: UILabel!

    var transaction: TransactionItem? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        hashLabel.text = transaction?.hash
        amountLabel.text = transaction?.amount
        feeLabel.text = feeText(fee: (transaction?.fee)!, size: (transaction?.size)!)
        memoLabel.text = transaction?.memo
        dateLabel.text = transaction?.date
        feeButton.isHidden = true
        bottomLabel.isHidden = true
        if(transaction?.blockheight == 0) {
            feeButton.isHidden = false
            bottomLabel.isHidden = false
            warniniglabel.text = "Unconfirmed transaction, please wait for block confirmations to gain trust in this transaction "
        } else if (AccountStore.shared.getBlockheight() - (transaction?.blockheight)! < 6) {
            let blocks = AccountStore.shared.getBlockheight() - (transaction?.blockheight)! + 1
            warniniglabel.text = String(format: "(%d/6) blocks confirmed", blocks)
        } else {
            warniniglabel.isHidden = true
        }
    }

    @IBAction func increaseFeeClicked(_ sender: Any) {
    }

    func feeText(fee: UInt32, size: UInt32) -> String {
        let perbyte = Double(fee/size)
        return String(format: "Transaction fee is %d satoshi, %.2f satoshi per byte", fee, perbyte)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        feeButton.layoutIfNeeded()
        feeButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}
