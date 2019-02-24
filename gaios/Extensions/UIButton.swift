//
//  UIButton.swift
//  gaios
//
//  Created by Dawson Walker on 2019-02-23.
//  Copyright © 2019 Blockstream Corporation. All rights reserved.
//

import UIKit

extension UIButton {
    func setDefaultButtonText(string: String, fontColor: UIColor = .white) {
        let attributedString = NSMutableAttributedString(string: string)
        attributedString.setFont(font: UIFont.systemFont(ofSize: 16, weight: .medium), stringValue: string)
        attributedString.setKerning(kerning: 0.8, stringValue: string)
        attributedString.setColor(color: fontColor, forText: string)
        self.setAttributedTitle(attributedString, for: .normal)
    }
    
}
