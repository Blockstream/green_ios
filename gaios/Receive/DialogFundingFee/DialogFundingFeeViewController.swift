import Foundation
import UIKit

enum FundingFeeAction {
    case cancel
    case learnMore
}
protocol DialogFundingFeeViewControllerDelegate: AnyObject {
    func didDismiss()
}
class DialogFundingFeeViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblTxt1: UILabel!
    @IBOutlet weak var lblTxt2: UILabel!
    @IBOutlet weak var btnLearnMore: UIButton!
    @IBOutlet weak var btnDismiss: UIButton!

    weak var delegate: DialogFundingFeeViewControllerDelegate?

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
        lblTitle.text = "Lightning Funding & Fees".localized
        lblTxt1.text = "Because Lightning is a separate network that runs on top of Bitcoin, your wallet occasionally requires funding to receive Lightning payments.".localized
        lblTxt2.text = "After each funding fee, future payments arrive instantly at near-zero fees until you reach your receive capacity.".localized
    }
    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        [lblTxt1, lblTxt2].forEach {
            $0.setStyle(.txtCard)
        }
        btnLearnMore.setStyle(.underline(txt: "id_learn_more".localized, color: UIColor.gAccent()))
        btnDismiss.backgroundColor = UIColor.gGrayCard()
        btnDismiss.cornerRadius = btnDismiss.frame.size.height / 2
    }
    func dismiss(_ action: FundingFeeAction) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            switch action {
            case .cancel:
                self.delegate?.didDismiss()
            case .learnMore:
                SafeNavigationManager.shared.navigate(ExternalUrls.lnFundingFee)
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
    @IBAction func btnDismiss(_ sender: Any) {
        dismiss(.cancel)
    }
    @IBAction func btnLearnMore(_ sender: Any) {
        dismiss(.learnMore)
    }
}
