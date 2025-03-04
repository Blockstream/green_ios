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
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized
    }
}
extension UIImage {
    func withBadge(iconColor: UIColor, badgeColor: UIColor = .red) -> UIImage {
        let render = UIGraphicsImageRenderer(size: size)
        return render.image { _ in
            let iconTintedImage = withRenderingMode(.alwaysTemplate)
            iconColor.setFill()
            iconTintedImage.draw(at: .zero)
            let badgeSize = CGSize(width: 6, height: 6)
            let badgeOrigin = CGPoint(x: size.width - badgeSize.width, y: 0)
            let badgeRect = CGRect(origin: badgeOrigin, size: badgeSize)
            let badgePath = UIBezierPath(ovalIn: badgeRect)
            badgeColor.setFill()
            badgePath.fill()
        }
        .withRenderingMode(.alwaysOriginal)
    }
}
