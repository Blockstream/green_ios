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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        walletAddressLabel.text = receiveAddress
        let uri = bip21Helper.btcURIforAddress(address: receiveAddress!)
        walletQRCode.image = QRImageGenerator.imageForText(text: uri, frame: walletQRCode.frame)
        amountTextfield.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.white])

        amountTextfield.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        self.hideKeyboardWhenTappedAround()
    }

    func generateQRCode(_ text: String, _ frame: CGRect) -> UIImage {
        let data = text.data(using: String.Encoding.ascii, allowLossyConversion: false)
        
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter!.setValue(data, forKey: "inputMessage")
        filter!.setValue("Q", forKey: "inputCorrectionLevel")
        
        let image = filter!.outputImage!
        let scaleX = frame.size.width / image.extent.size.width
        let scaleY = frame.size.height / image.extent.size.height
        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        return UIImage(ciImage: scaledImage)
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        let btc_amount: String = textField.text!

        guard let btc_amount_double = Double(btc_amount) else {
            estimateLabel.text = "~0.00 USD"
            return
        }

        walletQRCode.image = QRImageGenerator.imageForText(text: bip21Helper.btcURIforAmnount(address:self.receiveAddress!, amount: btc_amount_double), frame: walletQRCode.frame)

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
