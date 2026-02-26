import Foundation
import UIKit
import core
protocol DialogSwapJadeViewControllerDelegate: AnyObject {
    func didDismiss()
    func didEnable()
    func didSelectNotNow()
}

enum JadeSwapAction {
    case enable
    case notNow
    case cancel
    case learnMore
}

class DialogSwapJadeViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var img: UIImageView!
    @IBOutlet weak var btnEnable: UIButton!
    @IBOutlet weak var btnNotNow: UIButton!
    @IBOutlet weak var btnLearnMore: UIButton!

    weak var delegate: DialogSwapJadeViewControllerDelegate?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .dark)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.4)
        customBlurEffectView.frame = self.view.bounds

        let dimmedView = UIView()
        dimmedView.backgroundColor = .black.withAlphaComponent(0.3)
        dimmedView.frame = self.view.bounds
        containerView.addSubview(customBlurEffectView)
        containerView.addSubview(dimmedView)
        return containerView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)

        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            swipeDown.direction = .down
            self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTap))
            tappableBg.addGestureRecognizer(tapToClose)
    }

    deinit {
        print("deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @objc func didTap(gesture: UIGestureRecognizer) {

        dismiss(.cancel)
    }

    func setContent() {
        lblTitle.text = "Get More Out of Jade".localized
        lblHint.text = "Unlock swaps for this wallet.".localized
        btnEnable.setTitle("Enable Swaps".localized, for: .normal)
        btnNotNow.setTitle("Not Now".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle24)
        lblHint.setStyle(.txtCard)
        btnEnable.setStyle(.primary)
        btnNotNow.setStyle(.outlined)
        btnLearnMore.setStyle(.underline(txt: "Learn More".localized, color: UIColor.gAccent()))
    }

    func dismiss(_ action: JadeSwapAction) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            switch action {
            case .enable:
                self.delegate?.didEnable()
            case .notNow:
                self.delegate?.didSelectNotNow()
            case .cancel:
                self.delegate?.didDismiss()
            case .learnMore:
                SafeNavigationManager.shared.navigate(ExternalUrls.swapJadeGetMoreDialog)
            }
        })
    }

    @objc func didSwipe(gesture: UIGestureRecognizer) {

        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss(.cancel)
            default:
                break
            }
        }
    }
    @IBAction func btnEnable(_ sender: Any) {
        AnalyticsManager.shared.swapSetup(account: AccountsRepository.shared.current)
        dismiss(.enable)
    }
    @IBAction func btnNotNow(_ sender: Any) {
        dismiss(.notNow)
    }
    @IBAction func btnLearnMore(_ sender: Any) {
        dismiss(.learnMore)
    }
}
