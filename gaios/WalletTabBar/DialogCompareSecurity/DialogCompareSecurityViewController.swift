import Foundation
import UIKit
import gdk

enum CompareSecurityAction {
    case setupHardware
    case buyJade
    case none
}
protocol DialogCompareSecurityViewControllerDelegate: AnyObject {
    func onHardwareTap(_ action: CompareSecurityAction)
}

class DialogCompareSecurityViewController: UIViewController {
    enum State {
        case mobile
        case hardware
    }
    enum CtaType {
        case cta1
        case cta2
    }

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var fadeView: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var iconPlus: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var lblHint1: UILabel!
    @IBOutlet weak var lblHint2: UILabel!
    @IBOutlet weak var lblInfo1: UILabel!
    @IBOutlet weak var lblInfo2: UILabel!
    @IBOutlet weak var lblInfo3: UILabel!
    @IBOutlet weak var btnCta1: UIButton!
    @IBOutlet weak var btnCta2: UIButton!

    var state = State.mobile

    weak var delegate: DialogCompareSecurityViewControllerDelegate?

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

    @objc func didSwipe(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss(.none)
            default:
                break
            }
        }
    }

    @objc func didTap(gesture: UIGestureRecognizer) {
        dismiss(.none)
    }

    func setContent() {
        lblTitle.text = "Security Level".localized
        segmentedControl .setTitle("Mobile".localized, forSegmentAt: 0)
        segmentedControl .setTitle("Hardware".localized, forSegmentAt: 1)
        switch state {
        case .mobile:
            lblHint1.text = "Mobile".localized
            lblHint2.text = "Security Level: 1".localized
            lblInfo1.text = "Ideal for small amounts of bitcoin".localized
            lblInfo2.text = "Convenient spending".localized
            lblInfo3.text = "Keys stored on mobile device".localized
            btnCta1.setTitle("Selected".localized, for: .normal)
            btnCta1.setStyle(.primaryDisabled)
            btnCta2.isHidden = true
            icon.isHidden = false
            iconPlus.isHidden = true
        case .hardware:
            lblHint1.text = "Hardware".localized
            lblHint2.text = "Security Level: 2".localized
            lblInfo1.text = "Ideal for long-term bitcoin storage".localized
            lblInfo2.text = "Mitigates common attacks risks".localized
            lblInfo3.text = "Keys stored on specialized device".localized
            btnCta1.setTitle("Setup Hardware Wallet".localized, for: .normal)
            btnCta2.setStyle(.underline(txt: "Don’t have one? Buy a Jade".localized, color: UIColor.gAccent()))
            btnCta1.setStyle(.primary)
            btnCta2.isHidden = false
            btnCta2.setStyle(.outlined)
            icon.isHidden = true
            iconPlus.isHidden = false
        }
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        lblHint1.setStyle(.title)
        lblHint1.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        lblHint2.setStyle(.txtCard)
        lblInfo1.setStyle(.txt)
        lblInfo2.setStyle(.txt)
        lblInfo3.setStyle(.txt)
        segmentedControl.setStyle(SegmentedStyle.defaultStyle)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    func updateState() {
        UIView.animate(withDuration: 0.2, delay: 0.0, options: UIView.AnimationOptions.curveEaseOut, animations: { [weak self] in
            self?.fadeView.alpha = 0.0
        }, completion: { [weak self] (_) -> Void  in
            self?.setContent()
            UIView.animate(withDuration: 0.2, delay: 0.0, options: UIView.AnimationOptions.curveEaseIn, animations: { [weak self] in
                self?.fadeView.alpha = 1.0
            }, completion: nil)
        })
    }

    func dismiss(_ action: CompareSecurityAction) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            self.delegate?.onHardwareTap(action)
        })
    }

    @IBAction func segmentedControl(_ sender: Any) {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            state = .mobile
        case 1:
            state = .hardware
        default:
            break
        }
        updateState()
    }

    @IBAction func btnCta1(_ sender: Any) {
        switch state {
        case .mobile:
            // always disabled here
            break
        case .hardware:
            dismiss(.setupHardware)
        }
    }

    @IBAction func btnCta2(_ sender: Any) {
        switch state {
        case .mobile:
            // hidden here
            break
        case .hardware:
            dismiss(.buyJade)
        }
    }
}
