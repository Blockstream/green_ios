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

    func addArrow() {
        let arrow = UIImage(named: "nextArrow")
        self.setImage(arrow, for: .normal)
        self.imageEdgeInsets = UIEdgeInsets(top: 0, left: self.frame.width, bottom: 0, right: 0)

        guard let view = self.imageView else { return }
        self.titleEdgeInsets = UIEdgeInsets(top: 0, left: -self.imageView!.frame.width/2, bottom: 0, right: 0)
        self.bringSubview(toFront: view)
        if(self.layer.sublayers != nil) {
            self.layer.insertSublayer(view.layer, at: UInt32(self.layer.sublayers!.count))
        }
    }
}

//Gradient Button
extension UIButton {
    private static var gradientLayers = [UIButton: (CAGradientLayer, CALayer)]()

    var enabledGradientLayer: CAGradientLayer {
        get {
            return createGradients().0
        }
    }

    var disabledGradientLayer: CALayer {
        get {
            return createGradients().1
        }
    }

    private func createHorizontalGradientLayer(colours: [UIColor]) -> CAGradientLayer {
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.frame = self.bounds
        gradient.colors = colours.map { $0.cgColor }
        gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1.0, y: 0.5)
        return gradient
    }

    private func createEnabledGradient() -> CAGradientLayer {
        return createHorizontalGradientLayer(colours: [UIColor.customMatrixGreenDark(), UIColor.customMatrixGreen()])
    }

    private func createDisabledGradient() -> CALayer {
        let layer = CALayer()
        self.shadowColor = .clear
        layer.borderWidth = 1
        layer.borderColor = UIColor.disabledColor().cgColor
        return layer
    }

    private func createGradients() -> (CAGradientLayer, CALayer) {
        if UIButton.gradientLayers[self] == nil {
            UIButton.gradientLayers[self] = (createEnabledGradient(), createDisabledGradient())
        }
        return UIButton.gradientLayers[self]!
    }

    func setGradient(_ enable: Bool) {
        precondition(layer.sublayers == nil, "attempting to set multiple layers")
        if(enable) {
            //Handle if button has image view and bring it to the front

            if let imageView = self.imageView {
                layer.insertSublayer(enabledGradientLayer, below: imageView.layer)
            } else {
                layer.addSublayer(enabledGradientLayer)
            }
            self.shadowColor = .black
        } else {
            self.backgroundColor = .clear
            self.layer.borderColor = UIColor.disabledColor().cgColor
            self.layer.borderWidth = 1
            self.shadowColor = .clear
        }
        
        setNeedsDisplay()
    }

    func toggleGradient(_ enable: Bool) {
        if enable == isUserInteractionEnabled {
            return
        }
        if let sublayers = layer.sublayers {
            precondition(sublayers.contains(enable ? disabledGradientLayer : enabledGradientLayer))
            layer.replaceSublayer(enable ? disabledGradientLayer : enabledGradientLayer, with: enable ? enabledGradientLayer : disabledGradientLayer)

        } else {
            if let imageView = self.imageView {
                layer.insertSublayer(enable ? enabledGradientLayer : disabledGradientLayer, below: imageView.layer)
            } else {
                layer.addSublayer(enable ? enabledGradientLayer : disabledGradientLayer)
            }
        }
        self.backgroundColor = .clear
        self.shadowColor = enable ? .black : .clear
        setNeedsDisplay()
        isUserInteractionEnabled = enable
    }

    func updateGradientLayerFrame() {
        enabledGradientLayer.frame = bounds
        disabledGradientLayer.frame = bounds
    }
}
