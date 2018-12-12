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

    var transactionItem: TransactionItem!
    var rbfTransaction: Transaction? = nil
    var wallet: WalletItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        feeButton.isHidden = true
        if transactionItem?.blockHeight == 0 {
            warniniglabel.text = "Unconfirmed transaction, please wait for block confirmations to gain trust in this transaction "
        } else if AccountStore.shared.getBlockheight() - (transactionItem.blockHeight) < 6 {
            let blocks = AccountStore.shared.getBlockheight() - transactionItem.blockHeight + 1
            let localizedConfirmed = NSLocalizedString("id_blocks_confirmed", comment: "")
            warniniglabel.text = String(format: "(%d/6) %@", blocks, localizedConfirmed)
        } else {
            warniniglabel.isHidden = true
        }
        if transactionItem.canRBF {
            feeButton.isHidden = false
        }

        hashTitle.text = NSLocalizedString("id_hash", comment: "")
        dateTitle.text = NSLocalizedString("id_date", comment: "")
        feeTitle.text = NSLocalizedString("id_fee", comment: "")
        amountTitle.text = NSLocalizedString("id_amount", comment: "")
        memoTitle.text = NSLocalizedString("id_memo", comment: "")
        feeButton.setTitle(NSLocalizedString("id_increase_fee", comment: ""), for: .normal)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshTransaction(_:)), name: NSNotification.Name(rawValue: "outgoingTX"), object: nil)
    }

    func updateUI() {
        hashLabel.text = transactionItem.hash
        amountLabel.text = transactionItem.amount()
        feeLabel.text = feeText(fee: transactionItem.fee, size: transactionItem.size)
        memoLabel.text = transactionItem.memo
        dateLabel.text = transactionItem.date()
    }

    @objc func refreshTransaction(_ notification: NSNotification) {
        // FIXME: this code appears to think that hash, amount, fee or date can change on
        // an outgoing transaction. Probably needs to be extended to include actual pertinent
        // information in the case of an RBF but can be argued this controller shouldn't
        // be listening for notifications on behalf of the parent.
    }

    @IBAction func increaseFeeClicked(_ sender: Any) {
        let bgq = DispatchQueue.global(qos: .background)
        firstly {
            gaios.getTransactionDetails(txhash: transactionItem.hash)
        }.then(on: bgq) { (prevTx: [String: Any]) -> Promise<Transaction> in
            let details: [String: Any] = ["previous_transaction": prevTx["transaction"] as Any]
            return gaios.createTransaction(details: details)
        }.done { tx in
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
            let currentNetwork: String = getNetwork().rawValue.lowercased()
            let config = try getGdkNetwork(currentNetwork)
            let baseUrl = config!["tx_explorer_url"] as! String
            if let url = URL(string: baseUrl + transactionItem.hash) {
                UIApplication.shared.open(url, options: [:])
            }
        } catch {
            print("error to retrieve the url")
        }
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
}
