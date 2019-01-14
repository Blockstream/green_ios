import Foundation
import UIKit
import PromiseKit

class TransactionDetailViewController: UIViewController {


    @IBOutlet weak var hashLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var warniniglabel: UILabel!
    @IBOutlet weak var feeButton: UIButton!

    @IBOutlet weak var hashTitle: UILabel!
    @IBOutlet weak var dateTitle: UILabel!
    @IBOutlet weak var feeTitle: UILabel!
    @IBOutlet weak var amountTitle: UILabel!
    @IBOutlet weak var memoTitle: UILabel!
    @IBOutlet weak var viewInExplorerButton: UIButton!

    var transaction: Transaction!
    var rbfTransaction: Transaction? = nil
    var wallet: WalletItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("id_transaction_details", comment: "")
        hashTitle.text = NSLocalizedString("id_hash", comment: "")
        dateTitle.text = NSLocalizedString("id_date", comment: "")
        feeTitle.text = NSLocalizedString("id_fee", comment: "")
        amountTitle.text = NSLocalizedString("id_amount", comment: "")
        memoTitle.text = NSLocalizedString("id_memo", comment: "")
        viewInExplorerButton.setTitle(NSLocalizedString("id_view_in_explorer", comment: ""), for: .normal)
        feeButton.setTitle(NSLocalizedString("id_increase_fee", comment: ""), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshTransaction(_:)), name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshTransaction(_:)), name: NSNotification.Name(rawValue: EventType.Block.rawValue), object: nil)
        feeButton.layoutIfNeeded()
        feeButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
        updateUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Block.rawValue), object: nil)
    }

    func updateUI() {
        hashLabel.text = transaction.hash
        amountLabel.text = transaction.amount()
        feeLabel.text = feeText(fee: transaction.fee, size: transaction.size)
        memoLabel.text = transaction.memo
        dateLabel.text = transaction.date()
        if transaction.blockHeight == 0 {
            warniniglabel.isHidden = true
        } else if AccountStore.shared.getBlockheight() - (transaction.blockHeight) < 6 {
            let blocks = AccountStore.shared.getBlockheight() - transaction.blockHeight + 1
            let localizedConfirmed = NSLocalizedString("id_blocks_confirmed", comment: "")
            warniniglabel.text = String(format: "(%d/6) %@", blocks, localizedConfirmed)
        } else {
            warniniglabel.isHidden = true
        }
        if transaction.canRBF {
            feeButton.isHidden = false
        } else {
            feeButton.isHidden = true
        }
    }

    @objc func refreshTransaction(_ notification: NSNotification) {
        // FIXME: this code appears to think that hash, amount, fee or date can change on
        // an outgoing transaction. Probably needs to be extended to include actual pertinent
        // information in the case of an RBF but can be argued this controller shouldn't
        // be listening for notifications on behalf of the parent.
        Guarantee().done {
            self.updateUI()
        }
    }

    @IBAction func increaseFeeClicked(_ sender: Any) {
        let details: [String: Any] = ["previous_transaction": transaction.details, "fee_rate": transaction.feeRate, "subaccount": wallet.pointer]
        gaios.createTransaction(details: details).done { tx in
            self.rbfTransaction = tx
            self.performSegue(withIdentifier: "rbf", sender: self)
        }.catch { _ in
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcDetailsViewController {
            nextController.transaction = rbfTransaction
            nextController.wallet = wallet
        }
    }

    @IBAction func viewInExplorerClicked(_ sender: Any) {
        do {
            let currentNetwork: String = getNetwork().lowercased()
            let config = try getGdkNetwork(currentNetwork)
            let baseUrl = config!["tx_explorer_url"] as! String
            if let url = URL(string: baseUrl + transaction.hash) {
                UIApplication.shared.open(url, options: [:])
            }
        } catch {
            print("error to retrieve the url")
        }
    }

    func feeText(fee: UInt64, size: UInt64) -> String {
        let perbyte = Double(fee/size)
        return String(format: "%d satoshi, %.2f sat/vbyte", fee, perbyte)
    }
}
