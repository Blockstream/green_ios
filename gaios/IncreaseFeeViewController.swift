
import Foundation
import UIKit
import NVActivityIndicatorView

class IncreaseFeeViewController: UIViewController, NVActivityIndicatorViewable,  TwoFactorCallDelegate {

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
        startAnimating()
        DispatchQueue.global(qos: .background).async {
            wrap {
                var details = [String: Any]()
                details["previous_transaction"] = self.transaction.rawTransaction
                details["fee_rate"] = feeRate
                let newTransaction = try getSession().createTransaction(details: details)
                return try getSession().sendTransaction(details: newTransaction!)
            }.done { (result: TwoFactorCall) in
                 try TwoFactorCallHelper(result, delegate: self).resolve()
            }.catch { error in
                DispatchQueue.main.async {
                    self.onError(nil, text: error.localizedDescription)
                }
            }
        }
    }

    func onResolve(_ sender: TwoFactorCallHelper?) {
        let alert = TwoFactorCallHelper.CodePopup(sender!)
        self.present(alert, animated: true, completion: nil)
    }

    func onRequest(_ sender: TwoFactorCallHelper?) {
        let alert = TwoFactorCallHelper.MethodPopup(sender!)
        self.present(alert, animated: true, completion: nil)
    }

    func onDone(_ sender: TwoFactorCallHelper?) {
        stopAnimating()
        self.dismiss(animated: true, completion: nil)
    }

    func onError(_ sender: TwoFactorCallHelper?, text: String) {
        stopAnimating()
        print( text )
    }

    @IBAction func increaseFeeClicked(_ sender: Any) {
        if let amount = Double(amountTextField.text!) {
            let feeRate = amount * 1000
            increaseFee(feeRate: feeRate)
        }
    }

    @IBAction func cancelClicked(_ sender: Any) {
         self.dismiss(animated: true, completion: nil)
    }
}
