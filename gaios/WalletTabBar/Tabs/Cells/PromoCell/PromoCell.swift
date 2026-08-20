import UIKit
import core

class PromoCell: UICollectionViewCell {
    @IBOutlet weak var background: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var ctaButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var closeButton: UIButton!

    class var identifier: String { return String(describing: self) }

    private var onAction: (() -> Void)?
    private var onDismiss: (() -> Void)?

    private var imageTask: Task<Void, Never>?
    private var currentImageUrl: String?

    override func awakeFromNib() {
        super.awakeFromNib()

        background.setStyle(.defaultStyle)

        titleLabel.setStyle(.sectionTitle)
        titleLabel.textColor = .white

        descriptionLabel.setStyle(.txtSmaller)
        descriptionLabel.textColor = .gGrayTxt()

        ctaButton.setTitle(nil, for: .normal)

        closeButton.tintColor = .gGrayTxt()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        currentImageUrl = nil
    }

    func configure(with model: PromoCellModel, onAction: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onAction = onAction
        self.onDismiss = onDismiss

        let processedTitle = String(model.promo.title.prefix(28))
        let processedDescription = String(model.promo.description.prefix(90))
        let processedCtaLabel = String(model.promo.cta.label.prefix(20))

        titleLabel.text = processedTitle
        descriptionLabel.text = processedDescription

        let attr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gAccent(),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.systemFont(ofSize: 14.0, weight: .medium)
        ]
        let nsAttr = NSAttributedString(string: processedCtaLabel, attributes: attr)

        let ctaButtonIcon = UIImage(resource: .icSquaredOutSmall).withTintColor(.gAccent(), renderingMode: .alwaysTemplate).resize(16, 16)
        var ctaButtonConfig = UIButton.Configuration.plain()
        ctaButtonConfig.attributedTitle = AttributedString(nsAttr)
        ctaButtonConfig.image = ctaButtonIcon
        ctaButtonConfig.imagePlacement = .trailing
        ctaButtonConfig.imagePadding = 4
        ctaButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        ctaButton.configuration = ctaButtonConfig

        let bounds = CGRect(x: 0, y: 0, width: 128, height: 128)
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let fallbackImage = renderer.image { ctx in
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let colors = [
                UIColor.gAccent().withAlphaComponent(0.22).cgColor,
                UIColor.gAccent().withAlphaComponent(0.0).cgColor
            ] as CFArray
            
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
                // 40pt radius creates the 80x80 ellipse
                ctx.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: 40,
                    options: .drawsBeforeStartLocation
                )
            }
        }
        
        imageTask?.cancel()

        guard currentImageUrl != model.promo.imageUrl else { return }
        currentImageUrl = model.promo.imageUrl

        if let url = URL(string: model.promo.imageUrl), url.scheme?.lowercased() == "https" {
            let request = URLRequest(url: url)
            self.imageView.image = fallbackImage
            imageTask = Task { [weak self] in
                do {
                    let (data, _) = try await URLSession.shared.data(for: request)
                    if Task.isCancelled { return }
                    
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self?.imageView.image = image
                        }
                    }
                } catch {
                    logger.error("Failed to load promo image: \(error.localizedDescription)")
                }
            }
        } else {
            self.imageView.image = fallbackImage
        }
    }

    @IBAction func ctaTapped(_ sender: Any) {
        onAction?()
    }

    @IBAction func dismissTapped(_ sender: Any) {
        onDismiss?()
    }
}
