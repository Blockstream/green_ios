import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

actor QRGenerator {

    // Single context for performance reason
    private let context = CIContext(options: [.workingColorSpace: NSNull(), .useSoftwareRenderer: false])

    func generateStatic(
        text: String,
        size: CGSize,
        padding: CGFloat = 16,
        correction: String = "M",
        screenScale: CGFloat) -> UIImage? {
        guard let ciImage = makeCIImage(content: text, correction: correction) else {
            return nil
        }
        return scale(ciImage: ciImage, targetSize: size, padding: padding, screenScale: screenScale)
    }

    private nonisolated func makeCIImage(content: String, correction: String) -> CIImage? {
        guard let data = content.data(using: .ascii) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correction
        return filter.outputImage
    }
    private func scale(ciImage: CIImage, targetSize: CGSize, padding: CGFloat, screenScale: CGFloat) -> UIImage? {
        let moduleRect = ciImage.extent
        let availableSize = CGSize(
            width:  targetSize.width  - padding * 2,
            height: targetSize.height - padding * 2
        )
        guard availableSize.width > 0, availableSize.height > 0 else {
            return nil
        }
        let scale = min(availableSize.width  / moduleRect.width,
                        availableSize.height / moduleRect.height)
        
        // Affine transform: scale up then translate to centre within padded region.
        let scaledWidth  = moduleRect.width  * scale
        let scaledHeight = moduleRect.height * scale
        let xOffset = padding + (availableSize.width  - scaledWidth)  / 2
        let yOffset = padding + (availableSize.height - scaledHeight) / 2
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: xOffset / scale, y: yOffset / scale)
        let scaled = ciImage.transformed(by: transform)
        
        // Render into a screen-scale CGImage for maximum sharpness.
        let bitmapSize = CGSize(
            width:  targetSize.width  * screenScale,
            height: targetSize.height * screenScale
        )
        // Force black modules on white background (CIImage is transparent by default).
        let background = CIImage(color: .white)
            .cropped(to: CGRect(origin: .zero, size: bitmapSize))
        let composited = scaled
            .transformed(by: CGAffineTransform(scaleX: screenScale, y: screenScale))
            .composited(over: background)
        
        guard let cgImage = context.createCGImage(
            composited,
            from: CGRect(origin: .zero, size: bitmapSize)
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: screenScale, orientation: .up)
    }
    func precomputeFrames(
        contents: [String],
        size: CGSize,
        padding: CGFloat = 16,
        correction: String = "M",
        screenScale: CGFloat
    ) async throws -> [UIImage] {
        return try await withThrowingTaskGroup(of: (Int, UIImage).self) { group in
            for (index, content) in contents.enumerated() {
                group.addTask { [self] in
                    if let image = await self.generateStatic(
                        text: content,
                        size: size,
                        padding: padding,
                        correction: correction,
                        screenScale: screenScale) {
                        return (index, image)
                    }
                    throw NSError()
                }
            }
            // Re-order results (TaskGroup may complete out-of-order).
            var frames = [(Int, UIImage)]()
            frames.reserveCapacity(contents.count)
            for try await pair in group { frames.append(pair) }
            return frames.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
