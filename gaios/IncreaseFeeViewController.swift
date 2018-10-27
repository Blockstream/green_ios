
import Foundation
import UIKit

class IncreaseFeeViewController: UIViewController {

    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var increaseFeeButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var satoshiLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    var transaction: TransactionItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        backgroundView.addGestureRecognizer(tap)
        hideKeyboardWhenTappedAround()
        amountTextField.attributedPlaceholder = NSAttributedString(string: "0",
                                                                   attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
    }

    @objc func dismiss(recognizer: UITapGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func increaseFeeClicked(_ sender: Any) {
        if let amount = Double(amountTextField.text!) {
            do {
                var details = transaction.rawTransaction
                details["fee_rate"] = amount * 1024
                var newTransaction = try getSession().createTransaction(details: details)
                let factor = try getSession().sendTransaction(details: newTransaction!)
                let json = try factor.getStatus()
                let status = json!["status"] as! String
                if (status == "call") {
                    let call = try factor.call()
                    let jsonCall = try factor.getStatus()
                    let statusCall = jsonCall!["status"] as! String
                    print(statusCall)
                }
                print(status)
            } catch {
                print("increase failed")
            }
        }
    }

    @IBAction func cancelClicked(_ sender: Any) {
         self.dismiss(animated: true, completion: nil)
    }
}
