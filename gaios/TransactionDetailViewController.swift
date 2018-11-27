import Foundation
import UIKit

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

    var transaction_g: TransactionItem? = nil
    var bumpTransaction: [String:Any]?
    var pointer: UInt32 = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        feeButton.isHidden = true
        if(transaction_g?.blockHeight == 0) {
            warniniglabel.text = "Unconfirmed transaction, please wait for block confirmations to gain trust in this transaction "
        } else if (AccountStore.shared.getBlockheight() - (transaction_g?.blockHeight)! < 6) {
            let blocks = AccountStore.shared.getBlockheight() - (transaction_g?.blockHeight)! + 1
            let localizedConfirmed = NSLocalizedString("id_blocks_confirmed", comment: "")
            warniniglabel.text = String(format: "(%d/6) %@", blocks, localizedConfirmed)
        } else {
            warniniglabel.isHidden = true
        }
        if(transaction_g?.canRBF)! {
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
        hashLabel.text = transaction_g?.hash
        amountLabel.text = transaction_g?.amount()
        feeLabel.text = feeText(fee: (transaction_g?.fee)!, size: (transaction_g?.size)!)
        memoLabel.text = transaction_g?.memo
        dateLabel.text = transaction_g?.date()
    }

    @objc func refreshTransaction(_ notification: NSNotification) {
        // FIXME: this code appears to think that hash, amount, fee or date can change on
        // an outgoing transaction. Probably needs to be extended to include actual pertinent
        // information in the case of an RBF but can be argued this controller shouldn't
        // be listening for notifications on behalf of the parent.
    }

    @IBAction func increaseFeeClicked(_ sender: Any) {
        do {
            let txhash = transaction_g?.hash
            let rawTx = try getSession().getTransactionDetails(txhash: txhash!)
            var details = [String: Any]()
            details["previous_transaction"] = rawTx
            details["fee_rate"] = rawTx!["fee_rate"]
            bumpTransaction = try getSession().createTransaction(details: details)
            self.performSegue(withIdentifier: "next", sender: self)
        } catch {
            print("something went worng with creating subAccount")
            bumpTransaction = nil
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcDetailsViewController {
            nextController.wallet = nil
            nextController.selectedType = TransactionType.BTC
            do {
                nextController.transaction = try TransactionHelper(bumpTransaction!)
            } catch {
                print("something went worng with creating subAccount")
            }
        }
    }

    @IBAction func viewInExplorerClicked(_ sender: Any) {
        do {
            let currentNetwork: String = getNetwork().rawValue.lowercased()
            let config = try getGdkNetwork(currentNetwork)
            let baseUrl = config!["tx_explorer_url"] as! String
            if let url = URL(string: baseUrl + (transaction_g?.hash)! ) {
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
