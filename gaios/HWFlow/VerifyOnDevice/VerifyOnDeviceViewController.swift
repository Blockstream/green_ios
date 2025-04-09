import Foundation
import UIKit

class VerifyOnDeviceViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var icWallet: UIImageView!
    @IBOutlet weak var addressTextView: UITextView!

    @IBOutlet weak var addressView: UIView!
    @IBOutlet weak var copyView: UIView!
    @IBOutlet weak var btnCopy: UIButton!
    @IBOutlet weak var imgTopPadding: NSLayoutConstraint!

    var viewModel: VerifyOnDeviceViewModel!

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

        if viewModel.isLedger {
            icWallet.image = UIImage(named: "il_check_addr_ledger")
        } else {
            let isV2 = BleHwManager.shared.jade?.version?.boardType == .v2
            icWallet.image = JadeAsset.img(.select, isV2 ? .v2 : .v1)
        }

        if viewModel.isDismissible {
            handle.isHidden = false
        }
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
        if viewModel.isDismissible {
            dismiss()
        }
    }

    func setContent() {
        copyView.isHidden = false
        lblTitle.text = "id_verify_on_device".localized
        if viewModel.isRedeposit {
            lblTitle.text = "Verify redeposit address".localized
            copyView.isHidden = true
        }
        lblHint.text = "id_please_verify_that_the_address".localized
        btnCopy.setTitle("id_copy".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        btnCopy.cornerRadius = 4.0
        AddressDisplay.configure(address: viewModel.address,
                                 textView: addressTextView)
        if viewModel.isLedger {
            imgTopPadding.constant = 20.0
        }
    }

    @MainActor
    func dismiss() {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }

    @objc func didSwipe(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                if viewModel.isDismissible {
                    dismiss()
                }
            default:
                break
            }
        }
    }

    @IBAction func btnCopy(_ sender: Any) {
        UIPasteboard.general.string = viewModel.address
        DropAlert().info(message: "id_address_copied_to_clipboard".localized, delay: 2.0)
    }
}
