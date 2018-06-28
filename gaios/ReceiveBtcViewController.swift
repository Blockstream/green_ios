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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
        do {
            self.receiveAddress = try getSession().getReceiveAddress()
            walletAddressLabel.text = receiveAddress
            walletQRCode.image = generateQRCode(receiveAddress!, self.walletQRCode.frame)
            self.walletQRCode.image = self.generateQRCode(receiveAddress!, self.walletQRCode.frame)
        } catch {
            print("getting receive failed")
        }
        generateAddress().done { (address: String) in
            print(address)
        }.catch { _ in
            print("failed again")
        }
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

    func generateAddress() -> Promise<String> {
        return retry(session: getSession(), network: Network.TestNet) {
            return wrap { return try getSession().getReceiveAddress() }
        }
    }
}
