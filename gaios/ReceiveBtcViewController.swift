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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        walletAddressLabel.text = receiveAddress
        let uri = bip21Helper.btcURIforAddress(address: receiveAddress!)
        walletQRCode.image = QRImageGenerator.imageForTextDark(text: uri, frame: walletQRCode.frame)
        amountTextfield.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.white])

        amountTextfield.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        self.hideKeyboardWhenTappedAround()
    }

    @IBAction func switchButtonClicked(_ sender: Any) {
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        shareButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        let btc_amount: String = textField.text!

        guard let btc_amount_double = Double(btc_amount) else {
            estimateLabel.text = "~0.00 USD"
            return
        }

        walletQRCode.image = QRImageGenerator.imageForTextDark(text: bip21Helper.btcURIforAmnount(address:self.receiveAddress!, amount: btc_amount_double), frame: walletQRCode.frame)

        let satoshi: Int = Int(btc_amount_double * 100000000)
        let usd_amount = AccountStore.shared.satoshiToUSD(amount: satoshi)
        estimateLabel.text = String(format: "~%.2f USD", usd_amount)
    }

    @IBAction func copyButtonClicked(_ sender: Any) {
        UIPasteboard.general.string = receiveAddress
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        _ = navigationController?.popViewController(animated: true)
    }
}
