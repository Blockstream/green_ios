//
//  SendBtcDetailsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import UIKit

class SendBtcDetailsViewController: UIViewController {
    
    var toAddress: String? = nil
    @IBOutlet weak var lowFeeButton: DesignableButton!
    @IBOutlet weak var mediumFeeButton: DesignableButton!
    @IBOutlet weak var highFeeButton: DesignableButton!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var customfeeButton: DesignableButton!
    @IBOutlet weak var maxAmountLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    var feeLabel: UILabel = UILabel()
    var wallet: WalletItem? = nil
    @IBOutlet weak var reviewButton: UIButton!
    @IBOutlet weak var currencySwitch: UIButton!
    @IBOutlet weak var errorLabel: UILabel!

    var selectedType = TransactionType.FIAT
    var maxAmountBTC = 0
    var btcAmount: Double = 0
    var fee: UInt64 = 1
    var selectedButton : UIButton? = nil
    var g_payload: [String: Any]? = nil
    var priority: TransactionPriority? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        self.view.addGestureRecognizer(tapGesture)
        self.tabBarController?.tabBar.isHidden = true
        addressLabel.text = toAddress
        amountTextField.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                                   attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        amountTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        priority = SettingsStore.shared.getFeeSettings().0
        updatePriorityButtons()
        if (btcAmount != 0) {
            updateEstimate()
            let fiat = AccountStore.shared.btcToFiat(amount: btcAmount)
            amountTextField.text = String(format: "%.2f", fiat)
        }
        updateMaxAmountLabel()
        setButton()
    }

    func setButton() {
        if (selectedType == TransactionType.BTC) {
            currencySwitch.setTitle(SettingsStore.shared.getDenominationSettings(), for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.customMatrixGreen()
            currencySwitch.setTitleColor(UIColor.white, for: UIControlState.normal)
        } else {
            currencySwitch.setTitle(SettingsStore.shared.getCurrencyString(), for: UIControlState.normal)
            currencySwitch.backgroundColor = UIColor.clear
            currencySwitch.setTitleColor(UIColor.white, for: UIControlState.normal)
        }
    }

    func updateMaxAmountLabel() {
        if (selectedType == TransactionType.BTC) {
            //maxAmountBTC = wallet?.balance
            maxAmountLabel.text = String(format: "%f %@", maxAmountBTC, SettingsStore.shared.getDenominationSettings())
        } else {
            let maxFiat = maxAmountBTC //FIXME
           //maxFiat = AccountStore.shared.btcToFiat(amount: wallet?.balance)
            maxAmountLabel.text = String(format: "%f %@", maxFiat, SettingsStore.shared.getCurrencyString())

        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reviewButton.layoutIfNeeded()
        errorLabel.isHidden = true
        reviewButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
        updateButton()
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
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBTCConfirmationViewController {
            nextController.toAddress = toAddress!
            if ( selectedType == TransactionType.FIAT) {
                let amount = amountTextField.text!
                nextController.fiat_amount = btcAmount
                nextController.btc_amount = AccountStore.shared.fiatToBtc(amount: nextController.fiat_amount)
            } else {
                let amount = amountTextField.text!
                nextController.btc_amount = btcAmount
                nextController.fiat_amount = AccountStore.shared.btcToFiat(amount: nextController.btc_amount)
            }
            nextController.wallet = wallet
            nextController.satoshi_fee = Int(fee)
            nextController.satoshi_amount = Int(btcAmount * 100000000)
            nextController.payload = g_payload
            nextController.selectedType = selectedType
        }
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        let amount: String = textField.text!
        guard let amount_d = Double(amount) else {
            return
        }
        if (selectedType == TransactionType.BTC) {
            btcAmount = getDenominatedAmount(amount: amount_d)
        } else if (selectedType == TransactionType.FIAT) {
            btcAmount = AccountStore.shared.fiatToBtc(amount: amount_d)
        }
        updateEstimate()
    }

    func updateEstimate() {

        if (btcAmount == 0) {
            setLabel(button: selectedButton!, fee: 0)
            g_payload = nil
            updateButton()
            return
        }

        var details = [String: Any]()
        let satoshi: UInt64 = UInt64(btcAmount * 100000000)
        var toAddress = [String: Any]()
        toAddress["satoshi"] = satoshi
        toAddress["address"] = addressLabel.text

        details["fee_rate"] = fee
        details["addressees"] = [toAddress]

        do {
            let unspent = try getSession().getUnspentOutputs(subaccount: (wallet?.pointer)!, num_confs: 1)
            details["utxos"] = unspent?["array"]
            if (details.count == 0 || (details["utxos"] as! [Any]).count == 0) {
                g_payload = nil
                updateButton()
                setLabel(button: selectedButton!, fee: 0)
                return
            }
            print(details)
            let payload = try getSession().createTransaction(details: details)
            let error = payload!["error"] as! String
            if (error != "") {
                g_payload = nil
                updateButton()
                errorLabel.isHidden = false
                errorLabel.text = error
                setLabel(button: selectedButton!, fee: 0)
                //update error message
                return
            }
            errorLabel.isHidden = true
            g_payload = payload
            updateButton()
            let fee = payload!["fee"] as! UInt64
            setLabel(button: selectedButton!, fee: fee)
            return
        } catch {
            print("couldn't cteate transcation")
        }
        g_payload = nil
        updateButton()
        setLabel(button: selectedButton!, fee: 0)
    }

    func updateButton() {
        if (g_payload == nil) {
            if (reviewButton.layer.sublayers?.count == 2) {
                reviewButton.layer.sublayers?.removeFirst()
            }
            reviewButton.isUserInteractionEnabled = false
            reviewButton.backgroundColor = UIColor.lightGray
        } else {
            reviewButton.isUserInteractionEnabled = true
            reviewButton.backgroundColor = UIColor.customMatrixGreen()
            reviewButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
        }
    }

    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        amountTextField.resignFirstResponder()
    }

    func getDenominatedAmount(amount: Double) -> Double{
        let denomination = SettingsStore.shared.getDenominationSettings()
        var amount_denominated: Double = 0
        if(denomination == SettingsStore.shared.denominationPrimary) {
            amount_denominated = amount
        } else if (denomination == SettingsStore.shared.denominationMilli) {
            amount_denominated = amount / 1000
        } else if (denomination == SettingsStore.shared.denominationMicro){
            amount_denominated = amount / 1000000
        }
        return amount_denominated
    }

    func setLabel(button: UIButton, fee: UInt64) {
        feeLabel.removeFromSuperview()
        if(fee == 0) {
            return
        }
        feeLabel = UILabel(frame: CGRect(x: button.center.x, y: button.center.y + button.frame.size.height / 2 + 21, width: 150, height: 21))
        feeLabel.textAlignment = .center
        feeLabel.textColor = UIColor.customTitaniumLight()

        let usdValue:Double = AccountStore.shared.satoshiToUSD(amount: fee)
        let size = g_payload!["transaction_vsize"] as! UInt64
        let satoshiPerByte = fee / size
        feeLabel.text = String(format: "~%.2f %@ \n (%d satoshi / byte)", usdValue, SettingsStore.shared.getCurrencyString(), satoshiPerByte)
        feeLabel.numberOfLines = 2
        feeLabel.font = feeLabel.font.withSize(13)
        feeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(feeLabel)
        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 10).isActive = true
    }

    func updatePriorityButtons() {
        if (priority == TransactionPriority.Low) {
            lowFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            mediumFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            highFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            lowFeeButton.layer.borderWidth = 2
            highFeeButton.layer.borderWidth = 1
            customfeeButton.layer.borderWidth = 1
            mediumFeeButton.layer.borderWidth = 1
        } else if (priority == TransactionPriority.Medium) {
            mediumFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            lowFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            highFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            lowFeeButton.layer.borderWidth = 1
            highFeeButton.layer.borderWidth = 1
            customfeeButton.layer.borderWidth = 1
            mediumFeeButton.layer.borderWidth = 2
        } else if (priority == TransactionPriority.High) {
            lowFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            mediumFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            highFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
            customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
            lowFeeButton.layer.borderWidth = 1
            highFeeButton.layer.borderWidth = 2
            customfeeButton.layer.borderWidth = 1
            mediumFeeButton.layer.borderWidth = 1
        } else if (priority == TransactionPriority.Custom) {
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

    @IBAction func lowFeeClicked(_ sender: Any) {
        selectedButton = lowFeeButton
        fee = AccountStore.shared.getFeeRateLow()
        updateEstimate()
        priority = TransactionPriority.Low
        updatePriorityButtons()
    }

    @IBAction func mediumFeeClicked(_ sender: Any) {
        selectedButton = mediumFeeButton
        fee = AccountStore.shared.getFeeRateMedium()
        updateEstimate()
        priority = TransactionPriority.Medium
        updatePriorityButtons()
    }

    @IBAction func highFeeClicked(_ sender: Any) {
        selectedButton = highFeeButton
        fee = AccountStore.shared.getFeeRateHigh()
        updateEstimate()
        priority = TransactionPriority.High
        updatePriorityButtons()
    }

    @IBAction func customFeeClicked(_ sender: Any) {
        priority = TransactionPriority.Custom
        updatePriorityButtons()
        fee = 0
    }
}
