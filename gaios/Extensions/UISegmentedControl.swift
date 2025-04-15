import UIKit

enum SegmentedStyle {
    case defaultStyle
}

extension UISegmentedControl {
    func setStyle(_ type: SegmentedStyle) {
        switch type {
        case .defaultStyle:
            borderWidth = 1.0
            borderColor = UIColor.white.withAlphaComponent(0.1)
            backgroundColor = .black
        }
    }
}
