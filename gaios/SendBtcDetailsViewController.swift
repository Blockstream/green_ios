//
//  SendBtcDetailsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/26/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
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
    @IBOutlet weak var btcAmountEstimate: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    var feeLabel: UILabel = UILabel()
    var wallet: WalletItem? = nil
    var fee: Int = 1
    var btcAmount: Double = 0
    @IBOutlet weak var currencyLabel: UILabel!
    @IBOutlet weak var reviewButton: UIButton!

    @IBAction func nextButtonClicked(_ sender: UIButton) {
        self.performSegue(withIdentifier: "confirm", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBTCConfirmationViewController {
            nextController.toAddress = toAddress!
            let fiat_amount: String = amountTextField.text!
            if let fiat_d = Double(fiat_amount)  {
                nextController.fiat_amount = fiat_d
            }
            nextController.wallet = wallet
            nextController.satoshi_fee = fee
            nextController.btc_amount = btcAmount
            nextController.satoshi_amount = Int(btcAmount * 100000000)
        }
    }

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
        mediumFeeClicked(0)
        if (btcAmount != 0) {
            updateEstimate()
            let fiat = AccountStore.shared.btcToUSD(amount: btcAmount)
            amountTextField.text = String(format: "%.2f", fiat)
        }
        currencyLabel.text = SettingsStore.shared.getCurrencyString()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        reviewButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        let fiat_amount: String = textField.text!
        guard let fiat_d = Double(fiat_amount) else {
            let currency = SettingsStore.shared.getCurrencyString()!
            btcAmountEstimate.text = String(format: "~0.00 %@", currency)
            return
        }
        let bitcoin_amount = AccountStore.shared.USDtoBTC(amount: fiat_d)
        btcAmount = bitcoin_amount
        updateEstimate()
    }

    func updateEstimate() {
        btcAmountEstimate.text = String(format: "~%g BTC", btcAmount)
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        amountTextField.resignFirstResponder()
    }

    func setLabel(button: UIButton, fee: Int) {
        feeLabel.removeFromSuperview()
        feeLabel = UILabel(frame: CGRect(x: button.center.x, y: button.center.y + button.frame.size.height / 2 + 21, width: 150, height: 21))
        feeLabel.textAlignment = .center
        feeLabel.textColor = UIColor.customTitaniumLight()

        let usdValue:Double = AccountStore.shared.satoshiToUSD(amount: fee * 250)

        feeLabel.text = String(format: "~%.2f USD \n (1 satoshi / byte)", usdValue)
        feeLabel.numberOfLines = 2
        feeLabel.font = feeLabel.font.withSize(13)
        feeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(feeLabel)
        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: feeLabel, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: button, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 10).isActive = true
    }

    @IBAction func lowFeeClicked(_ sender: Any) {
        fee = AccountStore.shared.feeEstimatelow
        setLabel(button: lowFeeButton, fee: fee)
        lowFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
        mediumFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        highFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        lowFeeButton.layer.borderWidth = 2
        highFeeButton.layer.borderWidth = 1
        customfeeButton.layer.borderWidth = 1
        mediumFeeButton.layer.borderWidth = 1
    }

    @IBAction func mediumFeeClicked(_ sender: Any) {
        fee = AccountStore.shared.feeEstimateMedium
        setLabel(button: mediumFeeButton, fee: fee)
        mediumFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
        lowFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        highFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        lowFeeButton.layer.borderWidth = 1
        highFeeButton.layer.borderWidth = 1
        customfeeButton.layer.borderWidth = 1
        mediumFeeButton.layer.borderWidth = 2
    }

    @IBAction func highFeeClicked(_ sender: Any) {
        fee = AccountStore.shared.feeEstimateHigh
        setLabel(button: highFeeButton, fee: fee)
        lowFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        mediumFeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        highFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
        customfeeButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        lowFeeButton.layer.borderWidth = 1
        highFeeButton.layer.borderWidth = 2
        customfeeButton.layer.borderWidth = 1
        mediumFeeButton.layer.borderWidth = 1
    }

    @IBAction func customFeeClicked(_ sender: Any) {
        fee = 2
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
