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

    var feeLabel: UILabel = UILabel()
    var uiErrorLabel: UIErrorLabel!
    var wallet: WalletItem? = nil
    var selectedType = TransactionType.FIAT
    var fee: UInt64 = 1
    var selectedButton : UIButton? = nil
    var priority: TransactionPriority? = nil
    var transaction: Transaction!
    let blockTime = ["~ 2 Hours", "~ 1 Hour", "~ 10-20 Minutes", "Unknown (custom)"]

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
        priority = SettingsStore.shared.getFeeSettings().0
        updatePriorityButtons()
        updateMaxAmountLabel()
        setButton()
        reviewButton.setTitle(NSLocalizedString("id_review", comment: ""), for: .normal)
        recipientTitle.text = NSLocalizedString("id_recipient", comment: "")
        minerFeeTitle.text = NSLocalizedString("id_miner_fee", comment: "")
        lowFeeButton.setTitle(NSLocalizedString("id_low", comment: ""), for: .normal)
        mediumFeeButton.setTitle(NSLocalizedString("id_normal", comment: ""), for: .normal)
        highFeeButton.setTitle(NSLocalizedString("id_high", comment: ""), for: .normal)
        customfeeButton.setTitle(NSLocalizedString("id_custom", comment: ""), for: .normal)
    }

    func refresh() {
        let address = transaction.addressees[0].address
        let satoshi = transaction.addressees[0].satoshi
        let addresseesReadOnly = transaction.addresseesReadOnly
        let sendAll = transaction.sendAll

        addressLabel.text = address

        amountTextField.isUserInteractionEnabled = !addresseesReadOnly
        sendAllFundsButton.isUserInteractionEnabled = !addresseesReadOnly
        currencySwitch.isUserInteractionEnabled = !addresseesReadOnly

        if sendAll {
            amountTextField.text = "All"
            return
        }

        var textAmount: String
        if (amountTextField.text == nil || amountTextField.text!.isEmpty) {
            textAmount = "0"
        } else {
            textAmount = amountTextField.text!
        }
        let changed = UInt64(String.toBtc(value: textAmount, fromType: SettingsStore.shared.getDenominationSettings())!) == satoshi
        if (satoshi != 0 && !changed) {
            if (selectedType == TransactionType.BTC) {
                amountTextField.text = String.toBtc(satoshi: satoshi, toType: SettingsStore.shared.getDenominationSettings())
            } else {
                amountTextField.text = String.toFiat(satoshi: satoshi)
            }
        }
    }

    func setButton() {
        if (selectedType == TransactionType.BTC) {
            currencySwitch.setTitle(SettingsStore.shared.getDenominationSettings().rawValue, for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.customMatrixGreen()
            currencySwitch.setTitleColor(UIColor.white, for: UIControlState.normal)
        } else {
            currencySwitch.setTitle(SettingsStore.shared.getCurrencyString(), for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.clear
            currencySwitch.setTitleColor(UIColor.white, for: UIControlState.normal)
        }
    }

    func updateMaxAmountLabel() {
        guard let amount = wallet?.satoshi else { return }
        if (selectedType == TransactionType.BTC) {
            maxAmountLabel.text = String.formatBtc(satoshi: amount)
        } else {
            maxAmountLabel.text = String.formatBtc(satoshi: amount)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reviewButton.layoutIfNeeded()
        uiErrorLabel.isHidden = true
        refresh()
        updateEstimate()
    }

    @IBAction func sendAllFundsClick(_ sender: Any) {
        sendAllFundsButton.isSelected = !sendAllFundsButton.isSelected;
        if (sendAllFundsButton.isSelected) {
            amountTextField.text = "All"
        } else {
            amountTextField.text = ""
        }
        updateEstimate()
    }

    @IBAction func nextButtonClicked(_ sender: UIButton) {
        self.performSegue(withIdentifier: "confirm", sender: self)
    }

    @IBAction func switchCurrency(_ sender: Any) {
        if (selectedType == TransactionType.BTC) {
            selectedType = TransactionType.FIAT
        } else {
            selectedType = TransactionType.BTC
        }
        setButton()
        updateMaxAmountLabel()
        updateEstimate()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBTCConfirmationViewController {
            nextController.wallet = wallet
            nextController.transaction = transaction
        }
    }

    @objc func customFeeDidChange(_ textField: UITextField) {
        let amount: String = textField.text!
        guard let amount_i = Int(amount) else {
            return
        }
        fee = UInt64(1000 * amount_i)
        updateEstimate()
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        updateEstimate()
    }

    func updateEstimate() {
        let amount: String? = amountTextField.text
        var satoshi: UInt64 = 0
        if (amount == nil || amount!.isEmpty || amount! == "All" || Double(amount!) == nil) {
            satoshi = 0
        } else if (selectedType == TransactionType.BTC) {
            satoshi = UInt64(String.toBtc(value: amount!)!)!
        } else if (selectedType == TransactionType.FIAT) {
            satoshi = UInt64(String.toBtc(fiat: amount!)!)!
        }
        if (satoshi == 0 && amount! != "All") {
            setLabel(button: selectedButton!, fee: 0)
            updateButton(false)
            return
        }

        transaction.feeRate = fee

        if !transaction.addresseesReadOnly {
            let addressee = Addressee(address: addressLabel.text!, satoshi: satoshi)
            transaction.addressees = [addressee]
            transaction.sendAll = sendAllFundsButton.isSelected
        }

        gaios.createTransaction(transaction: transaction).done { tx in
            if !tx.error.isEmpty {
                throw TransactionError.invalid(localizedDescription: NSLocalizedString(tx.error, comment: ""))
            }
            self.transaction = tx
            self.refresh()
            self.uiErrorLabel.isHidden = true
            self.updateButton(true)
            self.setLabel(button: self.selectedButton!, fee: tx.fee)
        }.catch { error in
            if let txError = (error as? TransactionError) {
                switch txError {
                case .invalid(let localizedDescription):
                    self.uiErrorLabel.text = localizedDescription
                }
            } else {
                self.uiErrorLabel.text = error.localizedDescription
            }
            self.updateButton(false)
            self.uiErrorLabel.isHidden = false
            self.setLabel(button: self.selectedButton!, fee: 0)
        }
    }

    func updateButton(_ enable: Bool) {
       if !enable {
            if (self.reviewButton.layer.sublayers?.count == 2) {
                self.reviewButton.layer.sublayers?.removeFirst()
            }
            self.reviewButton.isUserInteractionEnabled = false
            self.reviewButton.backgroundColor = UIColor.lightGray
        } else {
            self.reviewButton.isUserInteractionEnabled = true
            self.reviewButton.backgroundColor = UIColor.customMatrixGreen()
        }
    }

    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        amountTextField.resignFirstResponder()
    }

    func setLabel(button: UIButton, fee: UInt64) {
        feeLabel.removeFromSuperview()
        if(fee == 0) {
            return
        }
        feeLabel = UILabel(frame: CGRect(x: button.center.x, y: button.center.y + button.frame.size.height / 2 + 10, width: 150, height: 21))
        feeLabel.textColor = UIColor.customTitaniumLight()

        
        let fiatValue: Double = Double(String.toFiat(satoshi: UInt64(fee))!)!
        let size = transaction.transactionSize
        let satoshiPerByte = fee / size
        var timeEstimate = ""
        feeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(feeLabel)
        if(button == lowFeeButton) {
            timeEstimate = blockTime[0]
            feeLabel.textAlignment = .left
            NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true
        } else if (button == mediumFeeButton) {
            timeEstimate = blockTime[1]
            feeLabel.textAlignment = .center
            NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        } else if (button == highFeeButton) {
            timeEstimate = blockTime[2]
            feeLabel.textAlignment = .center
            NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        } else {
            timeEstimate = blockTime[3]
            feeLabel.textAlignment = .right
            NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 0).isActive = true
        }
        feeLabel.text = String(format: "%d satoshi / byte \nTime: %@\nFee: %d satoshi / ~%.2f %@", satoshiPerByte, timeEstimate, fee, fiatValue, SettingsStore.shared.getCurrencyString())
        feeLabel.numberOfLines = 3
        feeLabel.font = feeLabel.font.withSize(13)

        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 10).isActive = true
        feeLabel.layoutIfNeeded()
    }

    func updatePriorityButtons() {
        if (priority == TransactionPriority.Low) {
            selectedButton = lowFeeButton
            fee = AccountStore.shared.getFeeRateLow()
            lowFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            mediumFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            highFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            lowFeeButton.layer.borderWidth = 2
            highFeeButton.layer.borderWidth = 1
            customfeeButton.layer.borderWidth = 1
            mediumFeeButton.layer.borderWidth = 1
        } else if (priority == TransactionPriority.Medium) {
            selectedButton = mediumFeeButton
            fee = AccountStore.shared.getFeeRateMedium()
            mediumFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            lowFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            highFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            lowFeeButton.layer.borderWidth = 1
            highFeeButton.layer.borderWidth = 1
            customfeeButton.layer.borderWidth = 1
            mediumFeeButton.layer.borderWidth = 2
        } else if (priority == TransactionPriority.High) {
            selectedButton = highFeeButton
            fee = AccountStore.shared.getFeeRateHigh()
            lowFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            mediumFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            highFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            lowFeeButton.layer.borderWidth = 1
            highFeeButton.layer.borderWidth = 2
            customfeeButton.layer.borderWidth = 1
            mediumFeeButton.layer.borderWidth = 1
        } else if (priority == TransactionPriority.Custom) {
            selectedButton = customfeeButton
            lowFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            mediumFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            highFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            customfeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            lowFeeButton.layer.borderWidth = 1
            highFeeButton.layer.borderWidth = 1
            customfeeButton.layer.borderWidth = 2
            mediumFeeButton.layer.borderWidth = 1
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
        alert.addAction(UIAlertAction(title: "CANCEL", style: .cancel, handler: { [weak alert] (_) in
            alert?.dismiss(animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let amount:String = alert!.textFields![0].text!
            guard let amount_i = Int(amount) else {
                self.setLabel(button: self.customfeeButton, fee: 0)
                return
            }
            self.fee = UInt64(1000 * amount_i)
            self.updateEstimate()
            self.updatePriorityButtons()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func lowFeeClicked(_ sender: Any) {
        priority = TransactionPriority.Low
        updatePriorityButtons()
        updateEstimate()
    }

    @IBAction func mediumFeeClicked(_ sender: Any) {
        priority = TransactionPriority.Medium
        updatePriorityButtons()
        updateEstimate()
    }

    @IBAction func highFeeClicked(_ sender: Any) {
        priority = TransactionPriority.High
        updatePriorityButtons()
        updateEstimate()
    }

    @IBAction func customFeeClicked(_ sender: Any) {
        priority = TransactionPriority.Custom
        showCustomFeePopup()
    }
}
