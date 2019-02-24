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
        self.semanticContentAttribute = .forceRightToLeft
    }
}

//Gradient Button
extension UIButton {
    private static var gradientLayers = [UIButton: (CAGradientLayer, CAGradientLayer)]()

    var enabledGradientLayer: CAGradientLayer {
        get {
            return createGradients().0
        }
    }

    var disabledGradientLayer: CAGradientLayer {
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

    private func createDisabledGradient() -> CAGradientLayer {
        return createHorizontalGradientLayer(colours: [UIColor.customTitaniumMedium(), UIColor.customTitaniumLight()])
    }

    private func createGradients() -> (CAGradientLayer, CAGradientLayer) {
        if UIButton.gradientLayers[self] == nil {
            UIButton.gradientLayers[self] = (createEnabledGradient(), createDisabledGradient())
        }
        return UIButton.gradientLayers[self]!
    }

    func setGradient(_ enable: Bool) {
        precondition(layer.sublayers == nil, "attempting to set multiple layers")
        layer.addSublayer(enable ? enabledGradientLayer : disabledGradientLayer)
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
            layer.addSublayer(enable ? enabledGradientLayer : disabledGradientLayer)
        }
        setNeedsDisplay()
        isUserInteractionEnabled = enable
    }

    func updateGradientLayerFrame() {
        enabledGradientLayer.frame = bounds
        disabledGradientLayer.frame = bounds
    }
}
