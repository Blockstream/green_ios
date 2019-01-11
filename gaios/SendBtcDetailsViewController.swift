import Foundation
import UIKit
import PromiseKit

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

    let blockTime = [NSLocalizedString("id_4_hours", comment: ""), NSLocalizedString("id_2_hours", comment: ""), NSLocalizedString("id_1030_minutes", comment: ""), NSLocalizedString("id_unknown_custom", comment: "")]

    var feeLabel: UILabel = UILabel()
    var uiErrorLabel: UIErrorLabel!
    var wallet: WalletItem? = nil
    var isFiat = false
    var transaction: Transaction!
    var amountData: [String: Any]? = nil

    var feeEstimates: [UInt64] = {
        var feeEstimates = [UInt64](repeating: 0, count: 4)
        let estimates = getFeeEstimates()
        for (i, v) in [24, 12, 3, 0].enumerated() {
            feeEstimates[i] = estimates[v]
        }

        guard let settings = getGAService().getSettings() else { return feeEstimates }
        if settings.customFeeRate != nil {
            feeEstimates[3] = UInt64(settings.customFeeRate!)
        }

        return feeEstimates
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
            amountTextField.isUserInteractionEnabled = false
            sendAllFundsButton.isUserInteractionEnabled = false
        }

        if let oldFeeRate = getOldFeeRate() {
            feeEstimates[feeRateButtons.count - 1] = oldFeeRate + 1
            var found = false
            for i in 0..<feeRateButtons.count - 1 {
                if oldFeeRate < feeEstimates[i] {
                    found = true
                    selectedFee = i
                    break
                }
            }
            if !found {
                selectedFee = feeRateButtons.count - 1
            }
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
            let textAmount = sendAllFundsButton.isSelected ? NSLocalizedString("id_all", comment: "") : amountData?[!isFiat ? settings.denomination.rawValue.lowercased() : "fiat"] as? String ?? String()
            amountTextField.text = textAmount
        }

        amountTextField.isEnabled = !sendAllFundsButton.isSelected && amountTextField.isUserInteractionEnabled
    }

    func setCurrencySwitch() {
        guard let settings = getGAService().getSettings() else { return }
        if !isFiat {
            currencySwitch.setTitle(settings.denomination.rawValue, for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.customMatrixGreen()
        } else {
            currencySwitch.setTitle(settings.getCurrency(), for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.clear
        }
        currencySwitch.setTitleColor(UIColor.white, for: UIControlState.normal)
    }

    func updateMaxAmountLabel() {
        wallet?.getBalance().get { balance in
            self.maxAmountLabel.text = String.formatBtc(satoshi: self.wallet?.satoshi)
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
        guard let settings = getGAService().getSettings() else { return }
        let amount = !amountTextField.text!.isEmpty ? amountTextField.text! : amountTextField.placeholder!
        let conversionKey = !isFiat ? settings.denomination.rawValue.lowercased() : "fiat"
        amountData = convertAmount(details: [conversionKey : amount])
        updateTransaction()
    }

    func updateTransaction() {
        transaction.sendAll = sendAllFundsButton.isSelected
        transaction.feeRate = feeEstimates[selectedFee]

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
            self.updateSummaryLabel(fee: tx.fee)
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
            self.updateSummaryLabel(fee: 0)
        }
    }

    func updateReviewButton(_ enable: Bool) {
        reviewButton.enableWithGradient(enable)
    }

    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        amountTextField.resignFirstResponder()
    }

    func updateSummaryLabel(fee: UInt64) {
        guard let settings = getGAService().getSettings() else { return }

        feeLabel.removeFromSuperview()

        if fee == 0 {
            return
        }

        feeLabel = UILabel(frame: CGRect(x: lowFeeButton.center.x, y: lowFeeButton.center.y + lowFeeButton.frame.size.height / 2 + 10, width: 150, height: 21))
        feeLabel.textColor = UIColor.customTitaniumLight()

        let fiatValue = String.toFiat(satoshi: fee)!
        let feeInBTC = String.toBtc(satoshi: fee, toType: settings.denomination)!
        let satoshiPerVByte = Double(transaction.feeRate) / 1000.0

        feeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(feeLabel)
        feeLabel.textAlignment = .left
        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: lowFeeButton, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true

        feeLabel.text = String(format: "%.1f satoshi / vbyte \n", satoshiPerVByte) +
            String(format: "%@: %@\n", NSLocalizedString("id_confirmation", comment: ""), blockTime[selectedFee]) +
            String(format: "%@: %@ %@ / ~%@ %@", NSLocalizedString("id_fee", comment: ""), feeInBTC, settings.denomination.rawValue, fiatValue, settings.getCurrency())
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
        highlightFeeRateButton(feeRateButtons[selectedFee]!)
    }

    func showCustomFeePopup() {
        let alert = UIAlertController(title: NSLocalizedString("id_set_custom_fee_rate", comment: ""), message: "satoshi / byte", preferredStyle: .alert)
        alert.addTextField { (textField) in
            let customFee = String(self.feeEstimates[self.feeRateButtons.count - 1] / 1000)
            textField.keyboardType = .numberPad
            textField.attributedPlaceholder = NSAttributedString(string: customFee,
                                                                          attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { [weak alert] (_) in
            alert?.dismiss(animated: true, completion: nil)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_save", comment: ""), style: .default) { [weak alert] (_) in
            let amount:String = alert!.textFields![0].text!
            guard let amount_i = Int(amount) else {
                return
            }
            self.selectedFee = self.feeRateButtons.count - 1
            self.feeEstimates[self.feeRateButtons.count - 1] = UInt64(1000 * amount_i)
            self.updateTransaction()
            self.updatePriorityButtons()
        })
        self.present(alert, animated: true, completion: nil)
    }

    private func onFeeChanged(_ selectedFee: Int) {
        self.selectedFee = selectedFee
        updatePriorityButtons()
        updateTransaction()
    }

    @IBAction func lowFeeClicked(_ sender: Any) {
        onFeeChanged(0)
    }

    @IBAction func mediumFeeClicked(_ sender: Any) {
        onFeeChanged(1)
    }

    @IBAction func highFeeClicked(_ sender: Any) {
        onFeeChanged(2)
    }

    @IBAction func customFeeClicked(_ sender: Any) {
        showCustomFeePopup()
    }
}
