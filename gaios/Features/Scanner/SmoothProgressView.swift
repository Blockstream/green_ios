import UIKit

final class SmoothProgressView: UIView {
    private let progressLayer = CAShapeLayer()
    private let trackLayer = CAShapeLayer()

    private var currentProgress: Float = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.white.withAlphaComponent(0.2).cgColor
        trackLayer.lineWidth = 8
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.lineWidth = 8
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 4, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.width - 4, y: bounds.midY))

        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    func setProgress(_ progress: Float, animated: Bool = true) {
        let pinnedProgress = max(0, min(1, progress))
        print("setProgress: \(pinnedProgress)")

        if animated {
            // 1. Capture the live visual position BEFORE touching the model layer.
            //    Falls back to currentProgress if no presentation layer exists yet.
            let from = progressLayer.presentation()?.strokeEnd
            ?? CGFloat(currentProgress)

            // 2. Commit the final value to the model layer immediately,
            //    with implicit animations disabled so Core Animation doesn't
            //    fire its own 0.25 s default animation on top of ours.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.strokeEnd = CGFloat(pinnedProgress)
            CATransaction.commit()

            // 3. Drive the visual from the snapshot to the new target.
            //    Because the model is already at pinnedProgress, the animation
            //    is purely cosmetic — no fillMode / isRemovedOnCompletion needed.
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = from          // always the live visual position
            animation.toValue   = pinnedProgress
            animation.duration  = 0.1
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.add(animation, forKey: "smoothProgress")
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.strokeEnd = CGFloat(pinnedProgress)
            CATransaction.commit()
        }

        currentProgress = pinnedProgress
    }

    func reset() {
        setProgress(0, animated: false)
        progressLayer.removeAllAnimations()
    }
}
