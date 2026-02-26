import Foundation
import UIKit
import gdk

extension UIImageView {

    @MainActor
    func qrCode(text: String) {
        image = QRImageGenerator.imageForTextWhite(text: text, frame: self.frame)
    }

    @MainActor
    func bcurQrCode(bcur: BcurEncodedData) {
        Task.detached { [weak self] in
            var currentIndex = 0
            while true {
                let hidden = await MainActor.run { [weak self] in
                    self?.isHidden ?? true
                }
                if hidden {
                    return
                }
                if currentIndex >= bcur.parts.count {
                    currentIndex = 0
                }
                let part = bcur.parts[currentIndex]
                await MainActor.run { [weak self] in
                    if let self {
                        self.image = QRImageGenerator.imageForTextWhite(text: part, frame: self.frame)
                    }
                }
                currentIndex += 1
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
