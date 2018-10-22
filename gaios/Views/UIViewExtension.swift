import UIKit

extension UIView {

    static func reuseIdentifier() -> String {
        return NSStringFromClass(classForCoder()).components(separatedBy: ".").last!
    }

    static func UINibForClass(_ bundle: Bundle? = nil) -> UINib {
        return UINib(nibName: reuseIdentifier(), bundle: bundle)
    }

    static func nibForClass() -> Self {
        return loadNib(self)

    }

    static func loadNib<A>(_ owner: AnyObject, bundle: Bundle = Bundle.main) -> A {

        let nibName = NSStringFromClass(classForCoder()).components(separatedBy: ".").last!

        let nib = bundle.loadNibNamed(nibName, owner: owner, options: nil)!

        for item in nib {
            if let item = item as? A {
                return item
            }
        }

        return nib.last as! A

    }

    func addTransitionFade(_ duration: TimeInterval = 0.5) {
        let animation = CATransition()

        animation.type = kCATransitionFade
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        animation.fillMode = kCAFillModeForwards
        animation.duration = duration

        layer.add(animation, forKey: "kCATransitionFade")

    }

}
