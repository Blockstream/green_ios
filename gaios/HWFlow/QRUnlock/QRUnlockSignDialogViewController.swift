import Foundation
import UIKit

protocol QRUnlockSignDialogViewControllerDelegate: AnyObject {
    func onTap(_ action: QRUnlockSignDialogAction)
}

enum QRUnlockSignDialogAction {
    case cancel
    case connect
    case unlocked
    case unlock
}

class QRUnlockSignDialogViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnsStack: UIStackView!
    @IBOutlet weak var stackBottom: NSLayoutConstraint!

    @IBOutlet weak var btnLearn: UIButton!
    @IBOutlet weak var btnConnect: UIButton!
    @IBOutlet weak var btnUnlocked: UIButton!
    @IBOutlet weak var btnUnlock: UIButton!

    weak var delegate: QRUnlockSignDialogViewControllerDelegate?

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
        btnConnect.isHidden = true
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
        lblTitle.text = "Unlock Jade".localized
        lblHint.text = "Unlock your Jade before signing the transaction.".localized

        btnLearn.setTitle("id_learn_more".localized, for: .normal)
        btnConnect.setTitle("Connect Jade via Bluetooth or USB".localized, for: .normal)
        btnUnlocked.setTitle("Jade already unlocked".localized, for: .normal)
        btnUnlock.setTitle("QR PIN unlock".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblHint.setStyle(.txt)

        btnLearn.setStyle(.inline)
        btnConnect.setStyle(.inline)
        btnConnect.setTitleColor(.white, for: .normal)
        btnUnlocked.setStyle(.outlinedWhite)
        btnUnlock.setStyle(.primary)
    }

    func dismiss(_ action: QRUnlockSignDialogAction) {
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

    @IBAction func btnLearn(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.qrModeAirGapUsage)
    }

    @IBAction func btnConnect(_ sender: Any) {
        dismiss(.connect)
    }

    @IBAction func btnUnlocked(_ sender: Any) {
        dismiss(.unlocked)
    }

    @IBAction func btnUnlock(_ sender: Any) {
        dismiss(.unlock)
    }
}
