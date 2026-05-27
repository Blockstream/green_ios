import AVFoundation
import UIKit
public extension UIImage {
    func resize(_ width: Int, _ height: Int) -> UIImage {
        let maxSize = CGSize(width: width, height: height)
        let availableRect = AVFoundation.AVMakeRect(
            aspectRatio: self.size,
            insideRect: .init(origin: .zero, size: maxSize)
        )
        let targetSize = availableRect.size
        let format = UIGraphicsImageRendererFormat()
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized
    }
}
extension UIImage {
    func withBadge(iconColor: UIColor, badgeColor: UIColor = .red, borderColor: UIColor? = nil, borderWidth: CGFloat = 0, badgeOffset: CGPoint = .zero) -> UIImage {
        let render = UIGraphicsImageRenderer(size: size)
        return render.image { _ in
            let iconTintedImage = withRenderingMode(.alwaysTemplate)
            iconColor.setFill()
            iconTintedImage.draw(at: .zero)
            
            let badgeSize = CGSize(width: 6, height: 6)
            let badgeOrigin = CGPoint(x: size.width - badgeSize.width + badgeOffset.x, y: badgeOffset.y)
            let badgeRect = CGRect(origin: badgeOrigin, size: badgeSize)
            
            if let borderColor = borderColor, borderWidth > 0 {
                let borderRect = badgeRect.insetBy(dx: -borderWidth, dy: -borderWidth)
                let borderPath = UIBezierPath(ovalIn: borderRect)
                borderColor.setFill()
                borderPath.fill()
            }
            
            let badgePath = UIBezierPath(ovalIn: badgeRect)
            badgeColor.setFill()
            badgePath.fill()
        }
        .withRenderingMode(.alwaysOriginal)
    }
}
extension UIImage {
    static var swipeTagKey: UInt8 = 0
    func setSwipeTag(_ tag: String) {
        objc_setAssociatedObject(self, &UIImage.swipeTagKey, tag, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    func swipeTag() -> String? {
        return objc_getAssociatedObject(self, &UIImage.swipeTagKey) as? String
    }
}
