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

        updatePriorityButtons()
        updateMaxAmountLabel()
        setButton()

        reviewButton.setTitle(NSLocalizedString("id_review", comment: ""), for: .normal)
        recipientTitle.text = NSLocalizedString("id_recipient", comment: "")
        minerFeeTitle.text = NSLocalizedString("id_miner_fee", comment: "")
        lowFeeButton.setTitle(NSLocalizedString("id_low", comment: ""), for: .normal)
        mediumFeeButton.setTitle(NSLocalizedString("id_medium", comment: ""), for: .normal)
        highFeeButton.setTitle(NSLocalizedString("id_high", comment: ""), for: .normal)
        customfeeButton.setTitle(NSLocalizedString("id_custom", comment: ""), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        reviewButton.layoutIfNeeded()

        refresh(false)
        updateEstimate()
    }

    func refresh(_ forceUpdate: Bool) {
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

        var update = forceUpdate
        if satoshi != amountData?["satoshi"] as? UInt64 ?? 0 {
            precondition(amountData == nil)
            amountData = convertAmount(details: ["satoshi": satoshi])
            update = true
        }

        if update {
            let textAmount = amountData?[selectedType == TransactionType.BTC ? SettingsStore.shared.getDenominationSettings().rawValue.lowercased() : "fiat"] as? String ?? String()
            amountTextField.text = textAmount
        }
    }

    func setButton() {
        if selectedType == TransactionType.BTC {
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
        refresh(true)
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
        let amount = !amountTextField.text!.isEmpty ? amountTextField.text! : amountTextField.placeholder!
        let conversionKey = selectedType == TransactionType.BTC ? SettingsStore.shared.getDenominationSettings().rawValue.lowercased() : "fiat"
        amountData = convertAmount(details: [conversionKey : amount])
        updateEstimate()
    }

    func updateEstimate() {
        reviewButton.isUserInteractionEnabled = false

        let satoshi = amountData?["satoshi"] as? UInt64 ?? 0

        if !transaction.addresseesReadOnly {
            let addressee = Addressee(address: addressLabel.text!, satoshi: satoshi)
            transaction.addressees = [addressee]
            transaction.sendAll = sendAllFundsButton.isSelected
        }
        transaction.feeRate = fee

        gaios.createTransaction(transaction: transaction).get { tx in
            self.transaction = tx
        }.done { tx in
            if !tx.error.isEmpty {
                throw TransactionError.invalid(localizedDescription: NSLocalizedString(tx.error, comment: ""))
            }
            self.refresh(false)
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

    func updatePriorityButtons() {
        lowFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        mediumFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        highFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        lowFeeButton.layer.borderWidth = 1
        highFeeButton.layer.borderWidth = 1
        customfeeButton.layer.borderWidth = 1
        mediumFeeButton.layer.borderWidth = 1

        if priority == TransactionPriority.Low {
            selectedButton = lowFeeButton
            fee = AccountStore.shared.getFeeRateLow()
            lowFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            lowFeeButton.layer.borderWidth = 2
        } else if priority == TransactionPriority.Medium {
            selectedButton = mediumFeeButton
            fee = AccountStore.shared.getFeeRateMedium()
            mediumFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            mediumFeeButton.layer.borderWidth = 2
        } else if priority == TransactionPriority.High {
            selectedButton = highFeeButton
            fee = AccountStore.shared.getFeeRateHigh()
            highFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            highFeeButton.layer.borderWidth = 2
        } else if priority == TransactionPriority.Custom {
            selectedButton = customfeeButton
            customfeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            customfeeButton.layer.borderWidth = 2
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
                self.setLabel(button: self.customfeeButton, fee: 0)
                return
            }
            self.fee = UInt64(1000 * amount_i)
            self.updateEstimate()
            self.updatePriorityButtons()
        })
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
