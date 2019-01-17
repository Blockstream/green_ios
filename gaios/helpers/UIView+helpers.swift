import UIKit

@IBDesignable
class DesignableView: UIView {
}

@IBDesignable
class DesignableButton: UIButton {
}

@IBDesignable
class DesignableLabel: UILabel {
}

extension UIView {

    @IBInspectable
    var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable
    var borderColor: UIColor? {
        get {
            if let color = layer.borderColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.borderColor = color.cgColor
            } else {
                layer.borderColor = nil
            }
        }
    }

    @IBInspectable
    var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.shadowRadius = newValue
        }
    }

    @IBInspectable
    var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.shadowOpacity = newValue
        }
    }

    @IBInspectable
    var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.shadowOffset = newValue
        }
    }

    @IBInspectable
    var shadowColor: UIColor? {
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.shadowColor = color.cgColor
            } else {
                layer.shadowColor = nil
            }
        }
    }

    func applyGradient(colours: [UIColor]) -> Void {
        self.applyGradient(colours: colours, locations: nil)
    }

    func applyGradient(colours: [UIColor], locations: [NSNumber]?) -> Void {
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.frame = self.bounds
        gradient.colors = colours.map { $0.cgColor }
        gradient.locations = locations
        gradient.startPoint = CGPoint(x: 1, y: 1)
        gradient.endPoint = CGPoint(x: 0, y: 0)
        self.layer.insertSublayer(gradient, at: 0)
    }

    // from https://www.hackingwithswift.com
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}

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
