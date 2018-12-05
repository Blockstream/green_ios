
import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class IncreaseFeeViewController: KeyboardViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var increaseFeeButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var satoshiLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    var transaction: TransactionItem!
    var feeLabel: UILabel = UILabel()
    var firstTime: Bool = true
    var errorLabel: UIErrorLabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        backgroundView.addGestureRecognizer(tap)
        amountTextField.attributedPlaceholder = NSAttributedString(string: "0",
                                                                   attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        titleLabel.text = NSLocalizedString("id_set_custom_fee_rate", comment: "")
        increaseFeeButton.setTitle(NSLocalizedString("id_increase_fee", comment: "").capitalized, for: .normal)
        cancelButton.setTitle(NSLocalizedString("id_cancel", comment: ""), for: .normal)
        errorLabel.isHidden = false

        // Set custom rate to 1 satoshi higher than the old rate
        let prevFeeRate = transaction.feeRate
        let hintFeeRate = (prevFeeRate + 1) / 1000
        amountTextField.attributedPlaceholder = NSAttributedString(string: String(format: "%0.3f", hintFeeRate), attributes:    [NSAttributedStringKey.foregroundColor : UIColor.gray])
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
        let bgq = DispatchQueue.global(qos: .background)
        var details = [String: Any]()
        let jsonData = try! JSONEncoder().encode(self.transaction)
        details["previous_transaction"] = String(data: jsonData, encoding: .utf8)
        details["fee_rate"] = feeRate

        firstly {
            self.errorLabel.isHidden = true
            startAnimating(type: NVActivityIndicatorType.ballRotateChase)
            return Guarantee()
        }.then(on: bgq) {
            createTransaction(details: details)
        }.then(on: bgq) { transaction in
            signTransaction(transaction: transaction)
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.compactMap(on: bgq) { result_dict in
            let result = result_dict["result"] as! [String: Any]
            return try getSession().sendTransaction(details: result)
        }.compactMap(on: bgq) { (call:TwoFactorCall) in
            try call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { result in
            self.dismiss(animated: true, completion: nil)
        }.catch { error in
            self.errorLabel.isHidden = false
            if let twofaError = error as? TwoFactorCallError {
                switch twofaError {
                case .failure(let localizedDescription):
                    self.errorLabel.text = localizedDescription
                }
            } else {
                self.errorLabel.text = error.localizedDescription
            }
        }
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
