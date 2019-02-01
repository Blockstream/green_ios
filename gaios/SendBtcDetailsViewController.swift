import Foundation
import UIKit
import PromiseKit

class SendBtcDetailsViewController: UIViewController {

    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var maxAmountLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var reviewButton: UIButton!
    @IBOutlet weak var currencySwitch: UIButton!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var recipientTitle: UILabel!
    @IBOutlet weak var sendAllFundsButton: UIButton!
    @IBOutlet weak var minerFeeTitle: UILabel!

    @IBOutlet weak var fastFeeButton: FeeButton!
    @IBOutlet weak var mediumFeeButton: FeeButton!
    @IBOutlet weak var slowFeeButton: FeeButton!
    @IBOutlet weak var customFeeButton: FeeButton!

    lazy var feeRateButtons = [fastFeeButton, mediumFeeButton, slowFeeButton, customFeeButton]

    let blockTime = [NSLocalizedString("id_1030_minutes", comment: ""), NSLocalizedString("id_2_hours", comment: ""), NSLocalizedString("id_4_hours", comment: ""), ""]

    var feeLabel: UILabel = UILabel()
    var uiErrorLabel: UIErrorLabel!
    var wallet: WalletItem? = nil
    var isFiat = false
    var transaction: Transaction!
    var amountData: [String: Any]? = nil

    var feeEstimates: [UInt64?] = {
        var feeEstimates = [UInt64?](repeating: 0, count: 4)
        let estimates = getFeeEstimates()
        for (i, v) in [3, 12, 24, 0].enumerated() {
            feeEstimates[i] = estimates[v]
        }
        feeEstimates[3] = nil
        return feeEstimates
    }()

    var minFeeRate: UInt64 = {
        return getFeeEstimates()[0]
    }()

    var selectedFee: Int = {
        guard let settings = getGAService().getSettings() else { return 0 }
        switch settings.transactionPriority {
        case .Low:
            return 0
        case .Medium:
            return 1
        case .High:
            return 2
        case .Custom:
            return 3
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("id_send", comment: "")
        self.tabBarController?.tabBar.isHidden = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        self.view.addGestureRecognizer(tapGesture)

        uiErrorLabel = UIErrorLabel(self.view)
        errorLabel.isHidden = true

        amountTextField.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                                   attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        amountTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        if transaction.addresseesReadOnly {
            amountTextField.isEnabled = false
            amountTextField.isUserInteractionEnabled = false
            sendAllFundsButton.isHidden = true
            maxAmountLabel.isHidden = true
        }

        if let oldFeeRate = getOldFeeRate() {
            feeEstimates[feeRateButtons.count - 1] = oldFeeRate + minFeeRate
            var found = false
            for i in 0..<feeRateButtons.count - 1 {
                guard let feeEstimate = feeEstimates[i] else { break }
                if oldFeeRate < feeEstimate {
                    found = true
                    selectedFee = i
                    break
                }
                feeRateButtons[i]?.isEnabled = false
            }
            if !found {
                selectedFee = feeRateButtons.count - 1
            }
        }

        fastFeeButton.setTitle(NSLocalizedString("id_fast", comment: ""))
        mediumFeeButton.setTitle(NSLocalizedString("id_medium", comment: ""))
        slowFeeButton.setTitle(NSLocalizedString("id_slow", comment: ""))
        customFeeButton.setTitle(NSLocalizedString("id_custom", comment: ""))
        sendAllFundsButton.setTitle(NSLocalizedString(("id_send_all_funds"), comment: ""), for: .normal)
        reviewButton.setTitle(NSLocalizedString("id_review", comment: ""), for: .normal)
        recipientTitle.text = NSLocalizedString("id_recipient", comment: "").uppercased()
        minerFeeTitle.text = NSLocalizedString("id_miner_fee", comment: "").uppercased()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if transaction.satoshi != 0 {
            updateAmountData(transaction.satoshi)
        }

        let address = transaction.addressees[0].address
        addressLabel.text = address

        updateReviewButton(false)
        updateFeeButtons()
        updateMaxAmountLabel()
        setCurrencySwitch()
        updateTransaction()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        reviewButton.updateGradientLayerFrame()
    }

    func getOldFeeRate() -> UInt64? {
        if let prevTx = transaction.details["previous_transaction"] as? [String: Any] {
            return prevTx["fee_rate"] as? UInt64
        }
        return nil
    }

    func updateAmountData(_ satoshi: UInt64) {
        let newAmountData = convertAmount(details: ["satoshi" : satoshi])
        if newAmountData?["satoshi"] as? UInt64 != amountData?["satoshi"] as? UInt64 {
            amountData = newAmountData
            updateAmountTextField(true)
        }
    }

    func updateAmountTextField(_ forceUpdate: Bool) {
        if forceUpdate {
            guard let settings = getGAService().getSettings() else { return }
            let textAmount = sendAllFundsButton.isSelected ? NSLocalizedString("id_all", comment: "") : amountData?[!isFiat ? settings.denomination.rawValue : "fiat"] as? String ?? String()
            amountTextField.text = textAmount
        }
        amountTextField.textColor = amountTextField.isEnabled ? UIColor.white : UIColor.lightGray
    }

    func setCurrencySwitch() {
        guard let settings = getGAService().getSettings() else { return }
        if !isFiat {
            currencySwitch.setTitle(settings.denomination.toString(), for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.customMatrixGreen()
        } else {
            currencySwitch.setTitle(settings.getCurrency(), for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.clear
        }
        currencySwitch.setTitleColor(UIColor.white, for: UIControlState.normal)
        updateFeeButtons()
    }

    func updateMaxAmountLabel() {
        guard let wallet = self.wallet else { return }
        wallet.getBalance().get { balance in
            self.maxAmountLabel.text = String.toBtc(satoshi: wallet.satoshi)
        }.done { _ in }.catch { _ in }
    }

    @IBAction func sendAllFundsClick(_ sender: Any) {
        sendAllFundsButton.isSelected = !sendAllFundsButton.isSelected;
        updateTransaction()
        updateAmountTextField(true)
    }

    @IBAction func nextButtonClicked(_ sender: UIButton) {
        self.performSegue(withIdentifier: "confirm", sender: self)
    }

    @IBAction func switchCurrency(_ sender: Any) {
        isFiat = !isFiat
        setCurrencySwitch()
        updateAmountTextField(true)
        updateMaxAmountLabel()
        updateTransaction()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBTCConfirmationViewController {
            nextController.wallet = wallet
            nextController.transaction = transaction
        }
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        guard var amountText = amountTextField.text else { return }
        amountText = amountText.replacingOccurrences(of: ",", with: ".")
        amountTextField.text = amountText
        guard let settings = getGAService().getSettings() else { return }
        let amount = !amountText.isEmpty ? amountText : "0"
        let conversionKey = !isFiat ? settings.denomination.rawValue : "fiat"
        amountData = convertAmount(details: [conversionKey : amount])
        updateTransaction()
    }

    func updateTransaction() {
        guard let feeEstimate = feeEstimates[selectedFee] else { return }
        transaction.sendAll = sendAllFundsButton.isSelected
        transaction.feeRate = feeEstimate

        if !transaction.addresseesReadOnly {
            let satoshi = amountData?["satoshi"] as? UInt64 ?? 0
            let addressee = Addressee(address: addressLabel.text!, satoshi: satoshi)
            transaction.addressees = [addressee]
        }

        gaios.createTransaction(transaction: transaction).get { tx in
            self.transaction = tx
        }.done { tx in
            if !tx.error.isEmpty {
                throw TransactionError.invalid(localizedDescription: NSLocalizedString(tx.error, comment: ""))
            }
            self.updateAmountData(tx.addressees[0].satoshi)
            self.uiErrorLabel.isHidden = true
            self.updateReviewButton(true)
            self.updateFeeButtons()
        }.catch { error in
            if let txError = (error as? TransactionError) {
                switch txError {
                case .invalid(let localizedDescription):
                    self.uiErrorLabel.text = localizedDescription
                }
            } else {
                self.uiErrorLabel.text = error.localizedDescription
            }
            self.uiErrorLabel.isHidden = false
            self.updateReviewButton(false)
            self.updateFeeButtons()
        }
    }

    func updateReviewButton(_ enable: Bool) {
        reviewButton.toggleGradient(enable)
    }

    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        amountTextField.resignFirstResponder()
    }

    func updateFeeButtons() {
        for i in 0..<feeEstimates.count {
            guard let feeButton = feeRateButtons[i] else { break }
            if feeButton.gestureRecognizers == nil && feeButton.isEnabled {
                let tap = UITapGestureRecognizer(target: self, action: #selector(clickFeeButton))
                feeButton.addGestureRecognizer(tap)
                feeButton.isUserInteractionEnabled = true
            }
            feeButton.isSelect = false
            feeButton.timeLabel.text = String(format: "%@", blockTime[i])
            guard let fee = feeEstimates[i] else {
                feeButton.feerateLabel.text = NSLocalizedString("id_set_custom_fee_rate", comment: "")
                break
            }
            let feeSatVByte = Double(fee) / 1000.0
            let feeSatoshi = UInt64(feeSatVByte * Double(transaction.size))
            let amount = isFiat ? String.toFiat(satoshi: feeSatoshi) : String.toBtc(satoshi: feeSatoshi)
            feeButton.feerateLabel.text = String(format: "%@ (%.1f satoshi / vbyte)", amount, feeSatVByte)
        }
        feeRateButtons[selectedFee]?.isSelect = true
    }

    func showFeeCustomPopup() {
        let alert = UIAlertController(title: NSLocalizedString("id_set_custom_fee_rate", comment: ""), message: "satoshi / byte", preferredStyle: .alert)
        alert.addTextField { (textField) in
            let feeRate: UInt64
            if let storedFeeRate = self.feeEstimates[self.feeRateButtons.count - 1] {
                feeRate = storedFeeRate
            } else if let oldFeeRate = self.getOldFeeRate() {
                feeRate = (oldFeeRate + self.minFeeRate)
            } else if let settings = getGAService().getSettings() {
                feeRate = UInt64(settings.customFeeRate ?? self.minFeeRate)
            } else {
                feeRate = self.minFeeRate
            }
            textField.keyboardType = .decimalPad
            textField.attributedPlaceholder = NSAttributedString(string: String(Double(feeRate) / 1000),
                                                                          attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { [weak alert] (_) in
            alert?.dismiss(animated: true, completion: nil)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_save", comment: ""), style: .default) { [weak alert] (_) in
            guard var amount = alert!.textFields![0].text else { return }
            amount = amount.replacingOccurrences(of: ",", with: ".")
            guard let number = Double(amount) else { return }
            self.selectedFee = self.feeRateButtons.count - 1
            self.feeEstimates[self.feeRateButtons.count - 1] = UInt64(1000 * number)
            self.updateFeeButtons()
            self.updateTransaction()
        })
        self.present(alert, animated: true, completion: nil)
    }

    @objc func clickFeeButton(_ sender: UITapGestureRecognizer){
        guard let view = sender.view else { return }
        switch view {
        case fastFeeButton:
            self.selectedFee = 0
            break
        case mediumFeeButton:
            self.selectedFee = 1
            break
        case slowFeeButton:
            self.selectedFee = 2
            break
        case customFeeButton:
            showFeeCustomPopup()
            break
        default:
            return
        }
        updateFeeButtons()
        updateTransaction()
    }
}
