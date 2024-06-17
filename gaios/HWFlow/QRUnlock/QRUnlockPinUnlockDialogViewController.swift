import Foundation
import UIKit

protocol QRUnlockPinUnlockDialogViewControllerDelegate: AnyObject {
    func onTap(_ action: QRUnlockPinUnlockDialogAction)
}

enum QRUnlockPinUnlockDialogAction {
    case learMore
    case pinUnlock
    case alreadyUnlocked
    case cancel
}

class QRUnlockPinUnlockDialogViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnsStack: UIStackView!
    @IBOutlet weak var stackBottom: NSLayoutConstraint!

    @IBOutlet weak var btnLearMore: UIButton!
    @IBOutlet weak var btnPinUnlock: UIButton!
    @IBOutlet weak var btnAlreadyUnlocked: UIButton!

    weak var delegate: QRUnlockPinUnlockDialogViewControllerDelegate?

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
        lblTitle.text = "Unlock Jade before signing via QR".localized
        lblHint.text = "Help text. QR Mode allows you to communicate with Green using Jade's camera and QR codes (instead of USB or Bluetooth). ".localized
        btnLearMore.setTitle("Learn more here".localized, for: .normal)
        btnPinUnlock.setTitle("PIN Unlock via QR".localized, for: .normal)
        btnAlreadyUnlocked.setTitle("Already unlocked via SeedQR".localized, for: .normal)
    }

    func setStyle() {
        cardView.layer.cornerRadius = 20
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        btnLearMore.setStyle(.inline)
        btnPinUnlock.setStyle(.primary)
        btnAlreadyUnlocked.setStyle(.inline)
        lblHint.setStyle(.txtCard)
    }

    func dismiss(_ action: QRUnlockPinUnlockDialogAction) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                self.delegate?.onTap(action)
            })
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

    @IBAction func btnLearMore(_ sender: Any) {
        dismiss(.learMore)
    }

    @IBAction func btnPinUnlock(_ sender: Any) {
        dismiss(.pinUnlock)
    }

    @IBAction func btnAlreadyUnlocked(_ sender: Any) {
        dismiss(.alreadyUnlocked)
    }

}
