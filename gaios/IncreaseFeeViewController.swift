
import Foundation
import UIKit

class IncreaseFeeViewController: UIViewController {

    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var increaseFeeButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var satoshiLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var lowButton: DesignableButton!
    @IBOutlet weak var mediumButton: DesignableButton!
    @IBOutlet weak var highButton: DesignableButton!
    var transaction: TransactionItem!
    var priority: TransactionPriority? = nil
    var feeLabel: UILabel = UILabel()
    var firstTime: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        backgroundView.addGestureRecognizer(tap)
        hideKeyboardWhenTappedAround()
        amountTextField.attributedPlaceholder = NSAttributedString(string: "0",
                                                                   attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        NotificationCenter.default.addObserver(self, selector: #selector(IncreaseFeeViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if(firstTime) {
            firstTime = false
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    @objc func keyboardWillShow() {
        priority = nil
        updatePriorityButtons()
    }

    @objc func dismiss(recognizer: UITapGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func lowButtonClicked(_ sender: Any) {
        if (priority == TransactionPriority.Low) {
            priority = nil
            updatePriorityButtons()
            return
        }
        priority = TransactionPriority.Low
        updatePriorityButtons()
    }

    @IBAction func mediumButtonClicked(_ sender: Any) {
        if (priority == TransactionPriority.Medium) {
            priority = nil
            updatePriorityButtons()
            return
        }
        priority = TransactionPriority.Medium
        updatePriorityButtons()
    }

    @IBAction func highButtonClicked(_ sender: Any) {
        if (priority == TransactionPriority.High) {
            priority = nil
            updatePriorityButtons()
            return
        }
        priority = TransactionPriority.High
        updatePriorityButtons()
    }

    func setButtonSelected(button: UIButton, selected: Bool) {
        if(selected) {
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.customMatrixGreen().cgColor
        } else {
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.customTitaniumLight().cgColor
        }
    }

    func updatePriorityButtons() {
        if (priority == TransactionPriority.Low) {
            setButtonSelected(button: lowButton, selected: true)
            setButtonSelected(button: mediumButton, selected: false)
            setButtonSelected(button: highButton, selected: false)
            setLabel(button: lowButton)
        } else if (priority == TransactionPriority.Medium) {
            setButtonSelected(button: lowButton, selected: false)
            setButtonSelected(button: mediumButton, selected: true)
            setButtonSelected(button: highButton, selected: false)
            setLabel(button: mediumButton)
        } else if (priority == TransactionPriority.High) {
            setButtonSelected(button: lowButton, selected: false)
            setButtonSelected(button: mediumButton, selected: false)
            setButtonSelected(button: highButton, selected: true)
            setLabel(button: highButton)
        } else if (priority == nil) {
            setButtonSelected(button: lowButton, selected: false)
            setButtonSelected(button: mediumButton, selected: false)
            setButtonSelected(button: highButton, selected: false)
            setLabel(button: lowButton)
        }
    }

    func getFeeForPriority(p: TransactionPriority?) -> UInt64 {
        if(p == TransactionPriority.Low) {
            return AccountStore.shared.getFeeRateLow()
        } else if(p == TransactionPriority.Medium) {
            return AccountStore.shared.getFeeRateMedium()
        } else if(p == TransactionPriority.High) {
            return AccountStore.shared.getFeeRateHigh()
        } else {
            return 0
        }
    }

    func setLabel(button: UIButton) {
        feeLabel.removeFromSuperview()
        if(priority == nil) {
            return
        }
        feeLabel = UILabel(frame: CGRect(x: button.center.x, y: button.center.y + button.frame.size.height / 2 + 21, width: 150, height: 21))
        feeLabel.textAlignment = .center
        feeLabel.textColor = UIColor.customTitaniumLight()
        let feeRate = getFeeForPriority(p: priority!)
        let satoshiPerByte: Double = Double(feeRate) / 1024
        let cost = feeRate * UInt64(transaction.size)
        let usdValue:Double = AccountStore.shared.satoshiToFiat(amount: cost)
        feeLabel.text = String(format: "~%.2f %@ \n (%.0f satoshi / byte)", usdValue, SettingsStore.shared.getCurrencyString(), satoshiPerByte)
        feeLabel.numberOfLines = 2
        feeLabel.font = feeLabel.font.withSize(13)
        feeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(feeLabel)
        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 10).isActive = true
    }

    func increaseFee(feeRate: Double) {
        do {
            var details = [String: Any]()
            details["previous_transaction"] = transaction.rawTransaction
            details["fee_rate"] = feeRate
            var newTransaction = try getSession().createTransaction(details: details)
            let factor = try getSession().sendTransaction(details: newTransaction!)
            let json = try factor.getStatus()
            let status = json!["status"] as! String
            if (status == "call") {
                let call = try factor.call()
                let jsonCall = try factor.getStatus()
                let statusCall = jsonCall!["status"] as! String
                if(statusCall == "done") {
                    self.dismiss(animated: true, completion: nil)
                }
            } else if(status == "request_code") {
                let methods = json!["methods"] as! NSArray
                if(methods.count > 1) {
                    self.performSegue(withIdentifier: "twoFactorSelector", sender: factor)
                } else {
                    let method = methods[0] as! String
                    let req = try factor.requestCode(method: method)
                    let status1 = try factor.getStatus()
                    let parsed1 = status1!["status"] as! String
                    if(parsed1 == "resolve_code") {
                        self.performSegue(withIdentifier: "twoFactor", sender: factor)
                    }
                }
            }
            print(status)
        } catch {
            print("increase failed")
        }
    }

    @IBAction func increaseFeeClicked(_ sender: Any) {
        if (priority != nil) {
            let feeRate = getFeeForPriority(p: priority)
            increaseFee(feeRate: Double(feeRate))
            return
        }
        if let amount = Double(amountTextField.text!) {
            let feeRate = amount * 1024
            increaseFee(feeRate: feeRate)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
        }
        if let nextController = segue.destination as? TwoFactorSlectorViewController {
            nextController.twoFactor = sender as? TwoFactorCall
        }
    }

    @IBAction func cancelClicked(_ sender: Any) {
         self.dismiss(animated: true, completion: nil)
    }
}
