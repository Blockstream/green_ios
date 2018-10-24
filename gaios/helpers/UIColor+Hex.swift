import Foundation
import UIKit

extension UIColor {
    class func customMatrixGreen() -> UIColor {
        return UIColor(red:0.0/255.0, green:180.0/255.0, blue:90.0/255.0, alpha:1);
    }

    class func customMatrixGreenDark() -> UIColor {
        return UIColor(red:27.0/255.0, green:119.0/255.0, blue:69.0/255.0, alpha:1);
    }

    class func customTitaniumDark() -> UIColor {
        return UIColor(named: "customTitaniumDark")!
    }

    class func customTitaniumMedium() -> UIColor {
        return UIColor(red:55.0/255.0, green:63.0/255.0, blue:69.0/255.0, alpha:1);
    }

    class func customTitaniumLight() -> UIColor {
        return UIColor(red:100.0/255.0, green:120.0/255.0, blue:128.0/255.0, alpha:1);
    }
}
