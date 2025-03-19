import UIKit

struct WelcomeViewModel {
    let title: String
    let hint: String
    let nextButtonTitle: String
    init() {
        self.title = "Your wallet has been created!".localized
        self.hint = "You are now ready to begin receiving, purchasing and storing bitcoin with Blockstream Wallet.".localized
        self.nextButtonTitle = "Continue".localized
    }
}
class WelcomeView: UIView {

    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var lblWelcomeTitle: UILabel!
    @IBOutlet weak var lblWelcomeHint: UILabel!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var animateView: UIView!
    var onTap: (() -> Void)?
    lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .dark)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.4)
        customBlurEffectView.frame = self.bounds

        let dimmedView = UIView()
        dimmedView.backgroundColor = .black.withAlphaComponent(0.3)
        dimmedView.frame = self.bounds
        containerView.addSubview(customBlurEffectView)
        containerView.addSubview(dimmedView)
        return containerView
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        Bundle.main.loadNibNamed("WelcomeView", owner: self, options: nil)
        contentView.setConstraints(self)
    }
    func configure(with viewModel: WelcomeViewModel, onTap: (() -> Void)?) {
        lblWelcomeTitle.setStyle(.txtBigger)
        lblWelcomeHint.setStyle(.txtCard)
        btnNext.setStyle(.primary)

        lblWelcomeTitle.text = viewModel.title
        lblWelcomeHint.text = viewModel.hint
        btnNext.setTitle(viewModel.nextButtonTitle, for: .normal)
        self.onTap = onTap

        let riveView = RiveModel.animationWallet.createRiveView()
        animateView.addSubview(riveView)
        riveView.frame = CGRect(x: 0.0, y: 0.0, width: animateView.frame.width, height: animateView.frame.height)
        addSubview(blurredView)
        sendSubviewToBack(blurredView)
    }

    @IBAction func btnNext(_ sender: Any) {
        onTap?()
    }
}
extension UIView {
    func setConstraints(_ container: UIView!) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.frame = container.frame
        container.addSubview(self)
        NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: container, attribute: .leading, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: container, attribute: .trailing, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: container, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: container, attribute: .bottom, multiplier: 1.0, constant: 0).isActive = true
    }
}
