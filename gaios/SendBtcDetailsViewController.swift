import Foundation
import UIKit

class SendBtcDetailsViewController: UIViewController {

    @IBOutlet weak var lowFeeButton: DesignableButton!
    @IBOutlet weak var mediumFeeButton: DesignableButton!
    @IBOutlet weak var highFeeButton: DesignableButton!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var customfeeButton: DesignableButton!
    @IBOutlet weak var maxAmountLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var reviewButton: UIButton!
    @IBOutlet weak var currencySwitch: UIButton!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var recipientTitle: UILabel!
    @IBOutlet weak var sendAllFundsButton: UIButton!
    @IBOutlet weak var minerFeeTitle: UILabel!

    lazy var feeRateButtons = [lowFeeButton, mediumFeeButton, highFeeButton, customfeeButton]

    var feeLabel: UILabel = UILabel()
    var uiErrorLabel: UIErrorLabel!
    var wallet: WalletItem? = nil
    var isFiat = false
    var feeRate: UInt64 = 1
    var selectedButton : UIButton? = nil
    var priority = SettingsStore.shared.getFeeSettings().0
    var transaction: Transaction!
    let blockTime = [NSLocalizedString("id_4_hours", comment: ""), NSLocalizedString("id_2_hours", comment: ""), NSLocalizedString("id_1030_minutes", comment: ""), NSLocalizedString("id_unknown_custom", comment: "")]
    var amountData: [String: Any]? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tabBarController?.tabBar.isHidden = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        self.view.addGestureRecognizer(tapGesture)

        uiErrorLabel = UIErrorLabel(self.view)
        errorLabel.isHidden = true

        amountTextField.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                                   attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        amountTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        if transaction.addresseesReadOnly {
            amountTextField.isUserInteractionEnabled = false
            sendAllFundsButton.isUserInteractionEnabled = false
        }

        updatePriorityButtons()
        updateMaxAmountLabel()
        setCurrencySwitch()

        lowFeeButton.setTitle(NSLocalizedString("id_low", comment: ""), for: .normal)
        mediumFeeButton.setTitle(NSLocalizedString("id_medium", comment: ""), for: .normal)
        highFeeButton.setTitle(NSLocalizedString("id_high", comment: ""), for: .normal)
        customfeeButton.setTitle(NSLocalizedString("id_custom", comment: ""), for: .normal)
        sendAllFundsButton.setTitle(NSLocalizedString(("id_send_all_funds"), comment: ""), for: .normal)
        reviewButton.setTitle(NSLocalizedString("id_review", comment: ""), for: .normal)

        recipientTitle.text = NSLocalizedString("id_recipient", comment: "")
        minerFeeTitle.text = NSLocalizedString("id_miner_fee", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if transaction.satoshi != 0 {
            updateAmountData(transaction.satoshi)
        }

        let address = transaction.addressees[0].address
        addressLabel.text = address

        updateReviewButton(false)

        updateTransaction()
    }

    func updateAmountData(_ satoshi: UInt64) {
        let newAmountData = convertAmount(details: ["satoshi" : satoshi])
        if newAmountData?["satoshi"] as! UInt64 != amountData?["satoshi"] as! UInt64 {
            amountData = newAmountData
            updateAmountTextField(true)
        }
    }

    func updateAmountTextField(_ forceUpdate: Bool) {
        if forceUpdate {
            let textAmount = sendAllFundsButton.isSelected ? "All" : amountData?[!isFiat ? SettingsStore.shared.getDenominationSettings().rawValue.lowercased() : "fiat"] as? String ?? String()
            amountTextField.text = textAmount
        }

        amountTextField.isEnabled = !sendAllFundsButton.isSelected && amountTextField.isUserInteractionEnabled
    }

    func setCurrencySwitch() {
        if !isFiat {
            currencySwitch.setTitle(SettingsStore.shared.getDenominationSettings().rawValue, for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.customMatrixGreen()
        } else {
            currencySwitch.setTitle(SettingsStore.shared.getCurrencyString(), for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.clear
        }
        currencySwitch.setTitleColor(UIColor.white, for: UIControlState.normal)
    }

    func updateMaxAmountLabel() {
        guard let amount = wallet?.satoshi else { return }
        maxAmountLabel.text = String.formatBtc(satoshi: amount)
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
        let amount = !amountTextField.text!.isEmpty ? amountTextField.text! : amountTextField.placeholder!
        let conversionKey = !isFiat ? SettingsStore.shared.getDenominationSettings().rawValue.lowercased() : "fiat"
        amountData = convertAmount(details: [conversionKey : amount])
        updateTransaction()
    }

    func updateTransaction() {
        reviewButton.isUserInteractionEnabled = false

        transaction.sendAll = sendAllFundsButton.isSelected
        transaction.feeRate = feeRate

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
            self.updateSummaryLabel(button: self.selectedButton!, fee: tx.fee)
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
            self.updateSummaryLabel(button: self.selectedButton!, fee: 0)
        }
    }

    func updateReviewButton(_ enable: Bool) {
       if !enable {
            self.reviewButton.applyHorizontalGradient(colours: [UIColor.customTitaniumMedium(), UIColor.customTitaniumLight()])
            self.reviewButton.isUserInteractionEnabled = false
        } else {
            self.reviewButton.applyHorizontalGradient(colours: [UIColor.customMatrixGreenDark(), UIColor.customMatrixGreen()])
            self.reviewButton.isUserInteractionEnabled = true
        }
    }

    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        amountTextField.resignFirstResponder()
    }

    func updateSummaryLabel(button: UIButton, fee: UInt64) {
        feeLabel.removeFromSuperview()
        if(fee == 0) {
            return
        }
        feeLabel = UILabel(frame: CGRect(x: button.center.x, y: button.center.y + button.frame.size.height / 2 + 10, width: 150, height: 21))
        feeLabel.textColor = UIColor.customTitaniumLight()

        
        let fiatValue = String.toFiat(satoshi: fee)!
        let feeInBTC = String.toBtc(satoshi: fee, toType: SettingsStore.shared.getDenominationSettings())!
        let satoshiPerVByte = Double(transaction.feeRate) / 1000.0
        var timeEstimate = ""
        feeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(feeLabel)
        feeLabel.textAlignment = .left
        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: lowFeeButton, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true

        if button == lowFeeButton {
            timeEstimate = blockTime[0]
        } else if button == mediumFeeButton {
            timeEstimate = blockTime[1]
        } else if button == highFeeButton {
            timeEstimate = blockTime[2]
        } else {
            timeEstimate = blockTime[3]
        }
        feeLabel.text = String(format: "%.1f satoshi / vbyte \nTime: %@\nFee: %@ %@ / ~%@ %@", satoshiPerVByte, timeEstimate, feeInBTC, SettingsStore.shared.getDenominationSettings().rawValue, fiatValue, SettingsStore.shared.getCurrencyString())
        feeLabel.numberOfLines = 3
        feeLabel.font = feeLabel.font.withSize(13)

        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: lowFeeButton, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 10).isActive = true
        feeLabel.layoutIfNeeded()
    }

    func highlightFeeRateButton(_ button: DesignableButton) {
        button.layer.borderColor = UIColor.customMatrixGreen().cgColor
        button.layer.borderWidth = 2
    }

    func resetFeeRateButton(_ button: DesignableButton) {
        button.layer.borderColor = UIColor.customTitaniumLight().cgColor
        button.layer.borderWidth = 1
    }

    func resetFeeRateButtons() {
        feeRateButtons.forEach { button in
            resetFeeRateButton(button!)
        }
    }

    func updatePriorityButtons() {
        resetFeeRateButtons()

        if priority == TransactionPriority.Low {
            selectedButton = lowFeeButton
            feeRate = AccountStore.shared.getFeeRateLow()
            highlightFeeRateButton(lowFeeButton)
        } else if priority == TransactionPriority.Medium {
            selectedButton = mediumFeeButton
            feeRate = AccountStore.shared.getFeeRateMedium()
            highlightFeeRateButton(mediumFeeButton)
        } else if priority == TransactionPriority.High {
            selectedButton = highFeeButton
            feeRate = AccountStore.shared.getFeeRateHigh()
            highlightFeeRateButton(highFeeButton)
        } else if priority == TransactionPriority.Custom {
            selectedButton = customfeeButton
            highlightFeeRateButton(customfeeButton)
        }
    }

    func showCustomFeePopup() {
        let alert = UIAlertController(title: "Custom fee rate", message: "satoshi / byte", preferredStyle: .alert)
        alert.addTextField { (textField) in
            let minFee = String(format: "%d", AccountStore.shared.getFeeRateMin() / 1000)
            textField.keyboardType = .numberPad
            textField.attributedPlaceholder = NSAttributedString(string: minFee,
                                                                          attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        }
        alert.addAction(UIAlertAction(title: "CANCEL", style: .cancel) { [weak alert] (_) in
            alert?.dismiss(animated: true, completion: nil)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] (_) in
            let amount:String = alert!.textFields![0].text!
            guard let amount_i = Int(amount) else {
                self.updateSummaryLabel(button: self.customfeeButton, fee: 0)
                return
            }
            self.feeRate = UInt64(1000 * amount_i)
            self.updateTransaction()
            self.updatePriorityButtons()
        })
        self.present(alert, animated: true, completion: nil)
    }

    private func onFeeChanged(_ priority: TransactionPriority) {
        self.priority = priority
        updatePriorityButtons()
        updateTransaction()
    }

    @IBAction func lowFeeClicked(_ sender: Any) {
        onFeeChanged(TransactionPriority.Low)
    }

    @IBAction func mediumFeeClicked(_ sender: Any) {
        onFeeChanged(TransactionPriority.Medium)
    }

    @IBAction func highFeeClicked(_ sender: Any) {
        onFeeChanged(TransactionPriority.High)
    }

    @IBAction func customFeeClicked(_ sender: Any) {
        priority = TransactionPriority.Custom
        showCustomFeePopup()
    }
}
