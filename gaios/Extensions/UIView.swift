import UIKit
import core

@IBDesignable
class DesignableView: UIView {
}

enum PanelStyle {
    case alert
    case bottomsheet
}

enum ElementStyle {
    case input
}

enum CardStyle {
    case defaultStyle
    case lightStyle
}

extension UIView {

    var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }

    var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

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

    var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.shadowRadius = newValue
        }
    }

    var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.shadowOpacity = newValue
        }
    }

    var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.shadowOffset = newValue
        }
    }

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

    func makeGradient(colours: [UIColor], locations: [NSNumber]?) -> CAGradientLayer {
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.frame = self.bounds
        gradient.colors = colours.map { $0.cgColor }
        gradient.locations = locations
        gradient.startPoint = CGPoint(x: 1, y: 1)
        gradient.endPoint = CGPoint(x: 0, y: 0)
        return gradient
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

    @objc func setup() {
        let nibName = String(describing: type(of: self))
        guard let view = loadViewFromNib(nibName) else { return }
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[v]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: ["v": view]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[v]|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: ["v": view]))
    }

    func loadViewFromNib(_ nibName: String) -> UIView? {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName, bundle: bundle)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }

    @objc func roundCorners(_ corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: bounds,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        self.layer.mask = mask
    }

    func rotate() {
        let rotation: CABasicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: -Double.pi * 2)
        rotation.duration = 4
        rotation.fromValue = 0.0
        rotation.isCumulative = true
        rotation.repeatCount = .greatestFiniteMagnitude
        self.layer.add(rotation, forKey: "rotationAnimation")
    }
}

extension UIView {
    func setStyle(_ type: PanelStyle) {
        switch type {
        case .alert:
            backgroundColor = UIColor.gGrayPanel()
            layer.cornerRadius = 10
            borderWidth = 1.0
            borderColor = UIColor.white.withAlphaComponent(0.1)
        case .bottomsheet:
            backgroundColor = UIColor.gGrayPanel()
            layer.cornerRadius = 20.0
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
    }
    func setStyle(_ type: ElementStyle) {
        switch type {
        case .input:
            backgroundColor = UIColor.gGrayElement()
        }
    }
    func setStyle(_ type: CardStyle) {
        switch type {
        case .defaultStyle:
            backgroundColor = UIColor.gGrayCard()
            layer.cornerRadius = 5
            borderWidth = 1.0
            borderColor = UIColor.gGrayCardBorder()
        case .lightStyle:
            backgroundColor = UIColor.gGrayPanel()
            layer.cornerRadius = 5
            borderWidth = 1.0
            borderColor = UIColor.white.withAlphaComponent(0.07)
        }
    }
}

public extension UIView {

    func pressAnimate(_ completionBlock: @escaping () -> Void) {
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.1,
                       delay: 0,
                       options: .curveEaseIn,
                       animations: {[weak self] in
            self?.alpha = 0.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.05,
                           delay: 0,
                           options: .curveEaseOut,
                           animations: {[weak self] in
                self?.alpha = 1.0
            }, completion: {[weak self] _ in
                self?.isUserInteractionEnabled = true
                completionBlock()
            })
        })
    }
}
