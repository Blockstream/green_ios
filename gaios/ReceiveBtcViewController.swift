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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        walletAddressLabel.text = receiveAddress
        walletQRCode.image = QRImageGenerator.imageForAddress(address: receiveAddress!, frame: walletQRCode.frame)
        amountTextfield.attributedPlaceholder = NSAttributedString(string: "0.00",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.white])
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
    
    @IBAction func copyButtonClicked(_ sender: Any) {
        UIPasteboard.general.string = receiveAddress
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        _ = navigationController?.popViewController(animated: true)
    }
}
