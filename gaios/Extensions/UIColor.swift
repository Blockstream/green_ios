import Foundation
import UIKit

extension UIColor {
    class func customTitaniumDark() -> UIColor {
        return UIColor(named: "customTitaniumDark")!
    }
    class func customDestructiveRed() -> UIColor {
        return UIColor(named: "customDestructiveRed")!
    }
    class func customGrayLight() -> UIColor {
        return UIColor(named: "customGrayLight")!
    }
    class func customTextFieldBg() -> UIColor {
        return UIColor(named: "customTextFieldBg")!
    }
    class func customBtnOff() -> UIColor {
        return UIColor(named: "customBtnOff")!
    }
    class func errorRed() -> UIColor {
        return UIColor(named: "errorRed")!
    }
    class func warningYellow() -> UIColor {
        return UIColor(named: "warningYellow")!
    }
    class func infoBlue() -> UIColor {
        return UIColor(named: "infoBlue")!
    }
    // gNamed
    class func gAccountLightBlue() -> UIColor {
        return UIColor(named: "gAccountLightBlue")!
    }
    class func gAccountOrange() -> UIColor {
        return UIColor(named: "gAccountOrange")!
    }
    class func gBlackBg() -> UIColor {
        return UIColor(named: "gBlackBg")!
    }
    class func gGrayBtn() -> UIColor {
        return UIColor(named: "gGrayBtn")!
    }
    class func gGrayCard() -> UIColor {
        return UIColor(named: "gGrayCard")!
    }
    class func gGreenMatrix() -> UIColor {
        return UIColor(named: "gGreenMatrix")!
    }
    class func gAccountTestGray() -> UIColor {
        return UIColor(named: "gAccountTestGray")!
    }
    class func gAccountTestLightBlue() -> UIColor {
        return UIColor(named: "gAccountTestLightBlue")!
    }
    class func gGrayTxt() -> UIColor {
        return UIColor(named: "gGrayTxt")!
    }
    class func gW40() -> UIColor {
        return UIColor(named: "gW40")!
    }
    class func gW60() -> UIColor {
        return UIColor(named: "gW60")!
    }
    class func gGreenFluo() -> UIColor {
        return UIColor(named: "gGreenFluo")!
    }
    class func gRedFluo() -> UIColor {
        return UIColor(named: "gRedFluo")!
    }
    class func gLightning() -> UIColor {
        return UIColor(named: "gLightning")!
    }
    class func gRedWarn() -> UIColor {
        return UIColor(named: "gRedWarn")!
    }
    class func gGreenTx() -> UIColor {
        return UIColor(named: "gGreenTx")!
    }
    class func gRedTx() -> UIColor {
        return UIColor(named: "gRedTx")!
    }
    class func gOrangeTx() -> UIColor {
        return UIColor(named: "gOrangeTx")!
    }
    class func gGrayPanel() -> UIColor {
        return UIColor(named: "gGrayPanel")!
    }
    class func gGrayElement() -> UIColor {
        return UIColor(named: "gGrayElement")!
    }
    class func gGrayCamera() -> UIColor {
        return UIColor(named: "gGrayCamera")!
    }
    class func gGrayCardBorder() -> UIColor {
        return UIColor(named: "gGrayCardBorder")!
    }
    class func gGrayTabBar() -> UIColor {
        return UIColor(named: "gGrayCardBorder")!
    }
    class func gWarnCardBg() -> UIColor {
        return UIColor(named: "gWarnCardBg")!
    }
    class func gWarnCardBorder() -> UIColor {
        return UIColor(named: "gWarnCardBorder")!
    }
    class func gWarnCardBgBlue() -> UIColor {
        return UIColor(named: "gWarnCardBgBlue")!
    }
    class func gWarnCardBorderBlue() -> UIColor {
        return UIColor(named: "gWarnCardBorderBlue")!
    }
    class func gAccent() -> UIColor {
        return UIColor(named: "gAccent")!
    }
}

extension UIColor {

    func lighter(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: abs(percentage) )
    }

    func darker(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage) )
    }

    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: min(red + percentage/100, 1.0),
                           green: min(green + percentage/100, 1.0),
                           blue: min(blue + percentage/100, 1.0),
                           alpha: alpha)
        } else {
            return nil
        }
    }
}
