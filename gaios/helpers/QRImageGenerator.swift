//
//  QRImageGenerator.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/4/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class QRImageGenerator {
    
    static func imageForText(text: String, frame: CGRect) -> UIImage? {
        let data = text.data(using: String.Encoding.ascii, allowLossyConversion: false)

        let filter = CIFilter(name: "CIQRCodeGenerator")
        guard let colorFilter = CIFilter(name: "CIFalseColor") else { return nil }
        filter!.setValue(data, forKey: "inputMessage")
        filter!.setValue("Q", forKey: "inputCorrectionLevel")
        colorFilter.setValue(filter!.outputImage, forKey: "inputImage")
        colorFilter.setValue(CIColor(color: UIColor.customMatrixGreen()), forKey: "inputColor1") // Background white
        colorFilter.setValue(CIColor(color: UIColor.customTitaniumDark()), forKey: "inputColor0")

        guard let qrCodeImage = colorFilter.outputImage
            else {
                return nil
        }
        let scaleX = frame.size.width / qrCodeImage.extent.size.width
        let scaleY = frame.size.height / qrCodeImage.extent.size.height
        let scaledImage = qrCodeImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        return UIImage(ciImage: scaledImage)
    }

    static func imageForTextDark(text: String, frame: CGRect) -> UIImage? {
        let data = text.data(using: String.Encoding.ascii, allowLossyConversion: false)

        let filter = CIFilter(name: "CIQRCodeGenerator")
        guard let colorFilter = CIFilter(name: "CIFalseColor") else { return nil }
        filter!.setValue(data, forKey: "inputMessage")
        filter!.setValue("Q", forKey: "inputCorrectionLevel")
        colorFilter.setValue(filter!.outputImage, forKey: "inputImage")
        colorFilter.setValue(CIColor(color: UIColor.clear), forKey: "inputColor1") // Background white
        colorFilter.setValue(CIColor(color: UIColor.customTitaniumDark()), forKey: "inputColor0")

        guard let qrCodeImage = colorFilter.outputImage
            else {
                return nil
        }
        let scaleX = frame.size.width / qrCodeImage.extent.size.width
        let scaleY = frame.size.height / qrCodeImage.extent.size.height
        let scaledImage = qrCodeImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        return UIImage(ciImage: scaledImage)
    }
}
