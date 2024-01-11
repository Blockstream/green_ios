import Foundation
import UIKit
import gdk

extension UIImageView {

    func qrCode(text: String) {
        image = QRImageGenerator.imageForTextWhite(text: text, frame: self.frame)
    }

    func bcurQrCode(bcur: BcurEncodedData) {
        Task {
            var currentIndex = 0
            while !isHidden {
                if currentIndex >= bcur.parts.count {
                    currentIndex = 0
                }
                let part = bcur.parts[currentIndex]
                await MainActor.run {
                    image = QRImageGenerator.imageForTextWhite(text: part, frame: frame)
                }
                currentIndex += 1
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            }
        }
    }
}
