import UIKit

/// A custom cell for displaying quote options from different providers
class QuoteCell: UITableViewCell {
    
    // MARK: - Constants
    
    private struct Constants {
        // Colors
        static let bestPriceGreen = UIColor(red: 0, green: 0.8, blue: 0.4, alpha: 1.0)
        static let secondaryTextAlpha: CGFloat = 0.6
        
        // Layout
        static let containerCornerRadius: CGFloat = 12
        static let bestPriceTagHeight: CGFloat = 20
        static let tagCornerRadius: CGFloat = 10
        static let bestQuoteMinHeight: CGFloat = 110
        static let cellPadding: CGFloat = 12
        static let tagPadding: CGFloat = 8
        static let spacerHeight: CGFloat = 16
        
        // Fonts
        static let initialsFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        static let providerNameFont = UIFont.systemFont(ofSize: 16, weight: .medium)
        static let receiveAmountTitleFont = UIFont.systemFont(ofSize: 13, weight: .regular)
        static let receiveAmountFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        static let bestPriceFont = UIFont.systemFont(ofSize: 10, weight: .bold)
    }
    
    // MARK: - Outlets
    
    @IBOutlet weak var initialsContainerView: UIView!
    @IBOutlet weak var initialsLabel: UILabel!
    @IBOutlet weak var providerNameLabel: UILabel!
    @IBOutlet weak var receiveAmountTitleLabel: UILabel!
    @IBOutlet weak var receiveAmountLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    
    // MARK: - Properties
    
    private var provider: MeldQuoteItem?
    private var bestPriceTag: UIView?
    private var additionalHeightConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        resetCell()
    }
    
    // MARK: - Public Methods
    
    /// Configures the cell with quote data
    /// - Parameters:
    ///   - quote: The quote item to display
    ///   - amount: The amount of BTC to receive
    ///   - isBestQuote: Whether this is the best (highest amount) quote
    func configure(with quote: MeldQuoteItem, amount: Float, isBestQuote: Bool = false) {
        self.provider = quote
        
        configureProviderInfo(providerName: quote.serviceProvider)
        configureAmountInfo(amount: amount)
        
        if isBestQuote {
            applyBestQuoteStyling()
        }
    }
    
    // MARK: - Private UI Setup
    
    private func setupUI() {
        configureBasicAppearance()
        configureContainerView()
        configureInitialsView()
        configureLabels()
    }
    
    private func configureBasicAppearance() {
        backgroundColor = .clear
        selectionStyle = .none
    }
    
    private func configureContainerView() {
        containerView.backgroundColor = UIColor(named: "gBlackBg")
        containerView.layer.cornerRadius = Constants.containerCornerRadius
        containerView.clipsToBounds = true
    }
    
    private func configureInitialsView() {
        initialsContainerView.layer.cornerRadius = initialsContainerView.bounds.width / 2
        initialsContainerView.clipsToBounds = true
    }
    
    private func configureLabels() {
        // Initials label
        initialsLabel.textColor = .white
        initialsLabel.font = Constants.initialsFont
        
        // Provider name
        providerNameLabel.textColor = .white
        providerNameLabel.font = Constants.providerNameFont
        
        // Amount title
        receiveAmountTitleLabel.text = "You Receive:"
        receiveAmountTitleLabel.textColor = UIColor.white.withAlphaComponent(Constants.secondaryTextAlpha)
        receiveAmountTitleLabel.font = Constants.receiveAmountTitleFont
        
        // Amount value
        receiveAmountLabel.textColor = .white
        receiveAmountLabel.font = Constants.receiveAmountFont
    }
    
    // MARK: - Private Cell Configuration
    
    private func configureProviderInfo(providerName: String) {
        // Set provider name
        providerNameLabel.text = providerName
        
        // Set initials
        let initials = getInitials(from: providerName)
        initialsLabel.text = initials
        initialsContainerView.backgroundColor = colorFromProviderName(providerName)
    }
    
    private func configureAmountInfo(amount: Float) {
        // Set amount
        let amountString = formatBitcoin(amount)
        receiveAmountLabel.text = amountString
    }
    
    private func resetCell() {
        // Reset basic properties
        initialsContainerView.backgroundColor = .darkGray
        initialsLabel.text = ""
        providerNameLabel.text = ""
        receiveAmountLabel.text = ""
        containerView.layer.borderWidth = 0
        
        // Reset color
        receiveAmountLabel.textColor = .white
        
        // Reset visibility
        receiveAmountTitleLabel.isHidden = false
        
        // Clean up best price tag
        bestPriceTag?.removeFromSuperview()
        bestPriceTag = nil
        
        // Remove additional constraints
        if let constraint = additionalHeightConstraint {
            containerView.removeConstraint(constraint)
            additionalHeightConstraint = nil
        }
    }
    
    private func applyBestQuoteStyling() {
        applyBestQuoteContainerStyle()
        addBestPriceTag()
        addVerticalSpacing()
        
        // Use green text for the amount of the best quote
        receiveAmountLabel.textColor = Constants.bestPriceGreen
    }
    
    private func applyBestQuoteContainerStyle() {
        // Add a subtle green border to highlight
        containerView.layer.borderWidth = 1.5
        containerView.layer.borderColor = Constants.bestPriceGreen.cgColor
        
        // Add extra height to the cell for the best quote
        additionalHeightConstraint = NSLayoutConstraint(
            item: containerView as Any,
            attribute: .height,
            relatedBy: .greaterThanOrEqual,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: Constants.bestQuoteMinHeight
        )
        containerView.addConstraint(additionalHeightConstraint!)
    }
    
    private func addBestPriceTag() {
        // Create tag container view
        let tagView = UIView()
        tagView.backgroundColor = Constants.bestPriceGreen
        tagView.layer.cornerRadius = Constants.tagCornerRadius
        
        // Create tag label
        let tagLabel = UILabel()
        tagLabel.text = "Best Price"
        tagLabel.textColor = .black
        tagLabel.font = Constants.bestPriceFont
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add views
        tagView.addSubview(tagLabel)
        tagView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(tagView)
        
        // Position the tag at the top right
        NSLayoutConstraint.activate([
            tagView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Constants.cellPadding),
            tagView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Constants.cellPadding),
            tagView.heightAnchor.constraint(equalToConstant: Constants.bestPriceTagHeight),
            
            tagLabel.leadingAnchor.constraint(equalTo: tagView.leadingAnchor, constant: Constants.tagPadding),
            tagLabel.trailingAnchor.constraint(equalTo: tagView.trailingAnchor, constant: -Constants.tagPadding),
            tagLabel.topAnchor.constraint(equalTo: tagView.topAnchor),
            tagLabel.bottomAnchor.constraint(equalTo: tagView.bottomAnchor)
        ])
        
        // Store reference to remove on reuse
        bestPriceTag = tagView
    }
    
    private func addVerticalSpacing() {
        // Move the amount down by adding a spacer view to create more vertical distance
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(spacerView)
        
        NSLayoutConstraint.activate([
            spacerView.heightAnchor.constraint(equalToConstant: Constants.spacerHeight),
            spacerView.topAnchor.constraint(equalTo: bestPriceTag!.bottomAnchor),
            spacerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            spacerView.widthAnchor.constraint(equalToConstant: 1) // Minimal width
        ])
    }
    
    // MARK: - Helper Methods
    
    /// Generates a pair of initials from a provider name
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count > 1 {
            let first = components[0].prefix(1)
            let second = components[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else if !name.isEmpty {
            return String(name.prefix(2)).uppercased()
        }
        return "--"
    }
    
    /// Creates a deterministic color based on a provider name
    private func colorFromProviderName(_ name: String) -> UIColor {
        let hash = abs(name.hashValue)
        let hue = CGFloat(hash % 360) / 360.0
        return UIColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0)
    }
    
    /// Formats a numeric Bitcoin amount as a string
    private func formatBitcoin(_ amount: Float) -> String {
        return String(format: "%.8f BTC", amount)
    }
} 
