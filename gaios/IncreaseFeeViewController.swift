
import Foundation
import UIKit

class IncreaseFeeViewController: UIViewController, TwoFactorCallDelegate {

    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var increaseFeeButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var satoshiLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    var transaction: TransactionItem!
    var feeLabel: UILabel = UILabel()
    var firstTime: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        backgroundView.addGestureRecognizer(tap)
        hideKeyboardWhenTappedAround()
        amountTextField.attributedPlaceholder = NSAttributedString(string: "0",
                                                                   attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        titleLabel.text = NSLocalizedString("id_set_custom_fee", comment: "")
        increaseFeeButton.setTitle(NSLocalizedString("id_increase_fee", comment: "").capitalized, for: .normal)
        cancelButton.setTitle(NSLocalizedString("id_cancel", comment: ""), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if(firstTime) {
            firstTime = false
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    @objc func dismiss(recognizer: UITapGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
    }

    func increaseFee(feeRate: Double) {
        do {
            var details = [String: Any]()
            details["previous_transaction"] = transaction.rawTransaction
            details["fee_rate"] = feeRate
            let newTransaction = try getSession().createTransaction(details: details)
            let factor = try getSession().sendTransaction(details: newTransaction!)
            let resultHelper = TwoFactorCallHelper(factor)
            resultHelper.delegate = self
            try resultHelper.resolve();
        } catch {
            print("increase failed")
        }
    }

    func onResolve(_ sender: TwoFactorCallHelper?) {
        self.performSegue(withIdentifier: "twoFactor", sender: sender!)
    }

    func onRequest(_ sender: TwoFactorCallHelper?) {
        self.performSegue(withIdentifier: "twoFactorSelector", sender: sender!)
    }

    func onDone(_ sender: TwoFactorCallHelper?) {
        self.dismiss(animated: true, completion: nil)
    }

    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        print( text )
    }

    @IBAction func increaseFeeClicked(_ sender: Any) {
        if let amount = Double(amountTextField.text!) {
            let feeRate = amount * 1000
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
