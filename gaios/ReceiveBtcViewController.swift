//
//  ReceiveBtcViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/22/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit
import PromiseKit

class ReceiveBtcViewController: UIViewController {

    @IBOutlet weak var walletAddressLabel: UILabel!
    @IBOutlet weak var walletQRCode: UIImageView!
    var receiveAddress: String? = nil
    @IBOutlet weak var amountTextfield: UITextField!
    @IBOutlet weak var estimateLabel: UILabel!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var fiatSwitchButton: UIButton!
    var selectedType = TransactionType.FIAT
    var amount: Double = 0
    @IBOutlet weak var typeLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        walletAddressLabel.text = receiveAddress
        updateQRCode(amount: 0)
        amountTextfield.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.white])

        amountTextfield.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        self.hideKeyboardWhenTappedAround()
        setButton()
        updateType()
        updateEstimate()
    }

    @IBAction func switchButtonClicked(_ sender: Any) {
        changeType()
    }

    func changeType() {
        if (selectedType == TransactionType.BTC) {
            selectedType = TransactionType.FIAT
        } else {
            selectedType = TransactionType.BTC
        }
        setButton()
        updateType()
        updateEstimate()
    }

    func setButton() {
        if (selectedType == TransactionType.BTC) {
            fiatSwitchButton.setTitle(SettingsStore.shared.getDenominationSettings(), for: UIControlState.normal)
            fiatSwitchButton.backgroundColor = UIColor.customMatrixGreen()
            fiatSwitchButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        } else {
            fiatSwitchButton.setTitle(SettingsStore.shared.getCurrencyString(), for: UIControlState.normal)
            fiatSwitchButton.backgroundColor = UIColor.clear
            fiatSwitchButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        }
    }

    func updateType() {
        if (selectedType == TransactionType.BTC) {
            typeLabel.text = SettingsStore.shared.getDenominationSettings()
        } else {
            typeLabel.text = SettingsStore.shared.getCurrencyString()
        }
    }

    func updateEstimate() {
        let amount: String = amountTextfield.text!

        guard let amount_double = Double(amount) else {
            if (selectedType == TransactionType.BTC) {
                estimateLabel.text = "~0.00 " + SettingsStore.shared.getCurrencyString()
            } else {
                estimateLabel.text = "~0.00 " + SettingsStore.shared.getDenominationSettings()
            }
            updateQRCode(amount: 0)
            return
        }

        if (selectedType == TransactionType.BTC) {
            let denomination = SettingsStore.shared.getDenominationSettings()
            var amount_denominated: Double = 0
            if(denomination == SettingsStore.shared.denominationPrimary) {
                amount_denominated = amount_double
            } else if (denomination == SettingsStore.shared.denominationMilli) {
                amount_denominated = amount_double / 1000
            } else if (denomination == SettingsStore.shared.denominationMicro){
                amount_denominated = amount_double / 1000000
            }
            let converted = AccountStore.shared.btcToFiat(amount: amount_denominated)
            estimateLabel.text = String(format: "~%.2f %@", converted, SettingsStore.shared.getCurrencyString())
            updateQRCode(amount: amount_denominated)
        } else {
            let converted = AccountStore.shared.fiatToBtc(amount: amount_double)
            updateQRCode(amount: converted)
            estimateLabel.text = String(format: "~%f %@", converted, SettingsStore.shared.getDenominationSettings())
        }
    }

    func updateQRCode(amount: Double) {
        if (amount == 0) {
            let uri = bip21Helper.btcURIforAddress(address: receiveAddress!)
            walletQRCode.image = QRImageGenerator.imageForTextDark(text: uri, frame: walletQRCode.frame)
        } else {
            walletQRCode.image = QRImageGenerator.imageForTextDark(text: bip21Helper.btcURIforAmnount(address:self.receiveAddress!, amount: amount), frame: walletQRCode.frame)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        shareButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        let btc_amount: String = textField.text!
        updateEstimate()
    }

    @IBAction func shareButtonClicked(_ sender: Any) {
        let activityViewController = UIActivityViewController(activityItems: [receiveAddress!] , applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true, completion: nil)
    }

    @IBAction func copyButtonClicked(_ sender: Any) {
        UIPasteboard.general.string = receiveAddress
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        _ = navigationController?.popViewController(animated: true)
    }
}

public enum TransactionType: UInt32 {
    case BTC = 0
    case FIAT = 1
}
