import UIKit
import Foundation

final class QRCodeView: UIView {

    var fps: Double = 4
    var padding: CGFloat = 16

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.layer.magnificationFilter = .nearest
        return iv
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        ai.color = UIColor.gAccent()
        return ai
    }()

    private let service = QRGenerator()

    /// Pre-computation task – cancelled when `configure()` is called again or the view deallocates.
    private var precomputeTask: Task<Void, Never>?

    /// Animation loop task – independently cancellable via `stopAnimation()`.
    private var animationTask: Task<Void, Never>?

    /// The pre-rendered frames shared between the precompute task and the animation loop.
    private var precomputedFrames: [UIImage] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }
    private func setupSubviews() {
        backgroundColor = .clear
        layer.cornerRadius = 12
        layer.masksToBounds = true
        addSubview(imageView)
        addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func reset() {
        imageView.image = nil
        stopAnimation()
        precomputeTask?.cancel()
    }

    func configure(frames contents: [String]) {
        stopAnimation()
        precomputeTask?.cancel()
        precomputedFrames = []
        imageView.image = nil
        imageView.isHidden = true
        activityIndicator.startAnimating()

        precomputeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let size = await MainActor.run { self.bounds.size }
                guard size != .zero else { return }

                let frames = try await service.precomputeFrames(
                    contents: contents,
                    size: CGSize(width: size.width, height: size.height),
                    padding: padding,
                    correction: contents.count == 1 ? "M" : "L",
                    screenScale: UIScreen.main.scale
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.precomputedFrames = frames
                    self.activityIndicator.stopAnimating()
                    self.startAnimation()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    print("[AnimatedQRCodeView] Pre-computation error: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Starts (or restarts) the animation loop.
    /// Safe to call multiple times – previous loop is cancelled first.
    func startAnimation() {
        stopAnimation()
        guard !precomputedFrames.isEmpty else { return }

        let isStatic = precomputedFrames.count == 1
        let frames = precomputedFrames          // capture value – no retain cycle
        let interval = 1.0 / max(fps, 0.1)     // clamp fps to sensible minimum
        let nanoseconds = UInt64(interval * 1_000_000_000)

        animationTask = Task { @MainActor [weak self] in
            var index = 0
            while !Task.isCancelled {
                guard let self else { return }
                self.imageView.isHidden = false
                self.imageView.image = frames[index]
                index = (index + 1) % frames.count
                if isStatic { return }
                do {
                    try await Task.sleep(nanoseconds: nanoseconds)
                } catch {
                    // Task.CancellationError – exit cleanly.
                    return
                }
            }
        }
    }

    /// Stops the animation loop without discarding pre-computed frames.
    /// Call `startAnimation()` to resume.
    func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }

    /// Returns `true` when the animation loop is running.
    var isAnimating: Bool { animationTask != nil }

    deinit {
        precomputeTask?.cancel()
        animationTask?.cancel()
    }
}

