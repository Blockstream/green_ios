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

    @IBOutlet weak var titlelabel: UILabel!
    @IBOutlet weak var hashTitle: UILabel!
    @IBOutlet weak var dateTitle: UILabel!
    @IBOutlet weak var feeTitle: UILabel!
    @IBOutlet weak var amountTitle: UILabel!
    @IBOutlet weak var memoTitle: UILabel!

    var transaction_g: TransactionItem? = nil
    var pointer: UInt32 = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        feeButton.isHidden = true
        if(transaction_g?.blockheight == 0) {
            warniniglabel.text = "Unconfirmed transaction, please wait for block confirmations to gain trust in this transaction "
        } else if (AccountStore.shared.getBlockheight() - (transaction_g?.blockheight)! < 6) {
            let blocks = AccountStore.shared.getBlockheight() - (transaction_g?.blockheight)! + 1
            let localizedConfirmed = NSLocalizedString("id_blocks_confirmed", comment: "")
            warniniglabel.text = String(format: "(%d/6) %@", blocks, localizedConfirmed)
        } else {
            warniniglabel.isHidden = true
        }
        if(transaction_g?.canRBF)! {
            feeButton.isHidden = false
        }

        titlelabel.text = NSLocalizedString("id_transaction_details", comment: "")
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
        amountLabel.text = transaction_g?.amount
        feeLabel.text = feeText(fee: (transaction_g?.fee)!, size: (transaction_g?.size)!)
        memoLabel.text = transaction_g?.memo
        dateLabel.text = transaction_g?.date
    }

    @objc func refreshTransaction(_ notification: NSNotification) {
        print(notification.userInfo ?? "")
        if let dict = notification.userInfo as NSDictionary? {
            if let txhash = dict["txhash"] as? String {
                AccountStore.shared.GDKQueue.async{
                    wrap {
                        try getSession().getTransactions(subaccount: self.pointer, page: 0)
                        }.done { (transactions: [String : Any]?) in
                            DispatchQueue.main.async {
                                let list = transactions!["list"] as! NSArray
                                for tx in list.reversed() {
                                    print(tx)
                                    let transaction = tx as! [String : Any]
                                    let hash = transaction["txhash"] as! String
                                    if (hash != txhash) {
                                        continue
                                    }
                                    let satoshi:UInt64 = transaction["satoshi"] as! UInt64
                                    let fee = transaction["fee"] as! UInt32
                                    let size = transaction["transaction_vsize"] as! UInt32
                                    let blockheight = transaction["block_height"] as! UInt32
                                    let memo = transaction["memo"] as! String

                                    let dateString = transaction["created_at"] as! String
                                    let type = transaction["type"] as! String
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateStyle = .medium
                                    dateFormatter.timeStyle = .short
                                    let date = Date.dateFromString(dateString: dateString)
                                    let formattedBalance: String = String.formatBtc(satoshi: satoshi)
                                    let adressees = transaction["addressees"] as! [String]
                                    let can_rbf = transaction["can_rbf"] as! Bool
                                    var counterparty = ""
                                    if (adressees.count > 0) {
                                        counterparty = adressees[0]
                                    }
                                    let formatedTransactionDate = Date.dayMonthYear(date: date)
                                    let item = TransactionItem(timestamp: dateString, address: counterparty, amount: formattedBalance, fiatAmount: "", date: formatedTransactionDate, btc: Double(satoshi), type: type, hash: hash, blockheight: blockheight, fee: fee, size: size, memo: memo, dateRaw: date, canRBF: can_rbf, rawTransaction: transaction)
                                    self.transaction_g = item
                                    self.updateUI()
                                }
                            }
                            print("success")
                        }.catch { error in
                            print("error")
                    }
                }
            }
        }
    }

    @IBAction func increaseFeeClicked(_ sender: Any) {
        let increaseFee = self.storyboard?.instantiateViewController(withIdentifier: "increaseFee") as! IncreaseFeeViewController
        increaseFee.transaction = transaction_g!
        increaseFee.providesPresentationContextTransitionStyle = true
        increaseFee.definesPresentationContext = true
        increaseFee.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        increaseFee.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        let navController = UINavigationController(rootViewController: increaseFee)
        navController.isNavigationBarHidden = true
        self.present(navController, animated: true, completion: nil)
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

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}
