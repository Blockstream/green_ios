import Foundation
import UIKit

enum GenuineCheckDialogAction {
    case next
    case cancel
}
protocol GenuineCheckDialogViewControllerDelegate: AnyObject {
    func onAction(_ : GenuineCheckDialogAction)
}

class GenuineCheckDialogViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var icJade: UIImageView!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var lblInfo: UILabel!
    weak var delegate: GenuineCheckDialogViewControllerDelegate?
    var viewModel: GenuineCheckDialogViewModel!

    var isDismissible = true

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
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTapToClose))
            tappableBg.addGestureRecognizer(tapToClose)
        handle.isHidden = !isDismissible
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
    }

    @objc func didTapToClose(gesture: UIGestureRecognizer) {
        if isDismissible {
            dismiss(.cancel)
        }
    }

    func setContent() {
        lblTitle.text = "New Jade Plus Connected".localized
        lblHint.text = "A new device has been detected, please set it up to start using it.".localized
        btnNext.setTitle("Genuine Check".localized, for: .normal)
        lblInfo.text = "Genuine Check is mandatory for first time Jade connection. This way we make sure that you have a safe Jade.".localized
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txtCard)
        btnNext.setStyle(.primary)
        lblInfo.setStyle(.txtCard)
    }

    @MainActor
    func dismiss(_ action: GenuineCheckDialogAction) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                self.delegate?.onAction(action)
            })
        })
    }

    @objc func didSwipe(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                if isDismissible {
                    dismiss(.cancel)
                }
            default:
                break
            }
        }
    }

    @IBAction func btnNext(_ sender: Any) {
        dismiss(.next)
    }
}
