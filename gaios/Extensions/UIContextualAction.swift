import UIKit
public extension UIContextualAction {
    private static var swipeTagKey: UInt8 = 0

    func setSwipeTag(_ tag: String) {
        objc_setAssociatedObject(self, &UIContextualAction.swipeTagKey, tag, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func swipeTag() -> String? {
        return objc_getAssociatedObject(self, &UIContextualAction.swipeTagKey) as? String
    }
}
