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
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customLightGray()])
        amountTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        mediumFeeClicked(0)
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        let fiat_amount: String = textField.text!
        guard let fiat_d = Double(fiat_amount) else {
            btcAmountEstimate.text = "~0.00 BTC"
            return
        }
        let bitcoin_amount = AccountStore.shared.USDtoBTC(amount: fiat_d)
        btcAmount = bitcoin_amount
        btcAmountEstimate.text = String(format: "~%g BTC", bitcoin_amount)
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
        mediumFeeButton.layer.borderColor = UIColor.customLightGray().cgColor
        highFeeButton.layer.borderColor = UIColor.customLightGray().cgColor
        customfeeButton.layer.borderColor = UIColor.customLightGray().cgColor
    }

    @IBAction func mediumFeeClicked(_ sender: Any) {
        fee = AccountStore.shared.feeEstimateMedium
        setLabel(button: mediumFeeButton, fee: fee)
        lowFeeButton.layer.borderColor = UIColor.customLightGray().cgColor
        mediumFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
        highFeeButton.layer.borderColor = UIColor.customLightGray().cgColor
        customfeeButton.layer.borderColor = UIColor.customLightGray().cgColor
    }

    @IBAction func highFeeClicked(_ sender: Any) {
        fee = AccountStore.shared.feeEstimateHigh
        setLabel(button: highFeeButton, fee: fee)
        lowFeeButton.layer.borderColor = UIColor.customLightGray().cgColor
        mediumFeeButton.layer.borderColor = UIColor.customLightGray().cgColor
        highFeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
        customfeeButton.layer.borderColor = UIColor.customLightGray().cgColor
    }

    @IBAction func customFeeClicked(_ sender: Any) {
        fee = 2
        lowFeeButton.layer.borderColor = UIColor.customLightGray().cgColor
        mediumFeeButton.layer.borderColor = UIColor.customLightGray().cgColor
        highFeeButton.layer.borderColor = UIColor.customLightGray().cgColor
        customfeeButton.layer.borderColor = UIColor.customMatrixGreen().cgColor
    }
}
